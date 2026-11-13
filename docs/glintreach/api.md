# GlintReach API (Phases 02–04)

Base path: `/api/v1/accounts/:account_id/glint_reach`

Every endpoint requires:
- An authenticated user who is an **administrator** of `:account_id` (otherwise `401`).
- The `glint_reach` feature enabled on the account (otherwise `403`).
- Access-token requests additionally need the account's `api_and_webhooks` feature (Chatwoot default).

All records are looked up through `Current.account`, so IDs from another account return `404`.
`account_id`, `created_by_id` and `status` are never accepted from request bodies.

Errors follow Chatwoot conventions: validation/transition errors `422`
`{ "message": "...", "attributes": [...] }`; locked campaign or bad filter `422 { "error": "..." }`;
missing record `404`.

Swagger sources: `swagger/paths/application/glint_reach/`, `swagger/definitions/resource/glint_reach_*.yml`.
Regenerate JSON with `bundle exec rake swagger:build` (see "Known limitations").

## Brand profile (Phase 03)
| Method | Path | Body | Notes |
| --- | --- | --- | --- |
| GET | `/brand_profile` | – | `{ brand_profile: {...} }` or `{ brand_profile: null }` when none exists |
| PUT | `/brand_profile` | `{ brand_profile: { name, description, website_url, products_services, target_audience, geographic_market, preferred_languages: [], voice_and_tone, messaging_guidelines, prohibited_claims, approved_ctas: [] } }` | Creates on first save, then updates. One profile per account |

Validation: `name` is required (max 255). Long text fields max 5,000. `website_url` must be absolute
http/https without credentials (max 2,048) and is **never fetched**. `preferred_languages` holds at
most 10 codes like `en` or `pt-BR`. `approved_ctas` holds at most 20 entries of 100 characters each.
Lists are trimmed and de-duplicated.

## Campaigns
| Method | Path | Body / params | Notes |
| --- | --- | --- | --- |
| GET | `/campaigns` | `page`, `status`, `search` | 25/page, `updated_at desc`; archived hidden unless `status=archived`. Returns `{ meta: { count, current_page }, payload: [...] }` |
| POST | `/campaigns` | `{ campaign: { name, objective, brief, target_audience, starts_at, ends_at } }` | Created as `draft`; creator = current user |
| GET | `/campaigns/:id` | – | Includes `content_items[].variants[]` |
| PATCH | `/campaigns/:id` | same as create | `422` if `completed`/`archived` |
| DELETE | `/campaigns/:id` | – | **Archives** (from draft/paused/completed); `422` from active |
| POST | `/campaigns/:id/transition` | `{ status }` | See lifecycle |

`objective`: `awareness | engagement | traffic | leads | sales`

Phase 03 brief fields (create/update): `offer` (max 5,000), `key_message` (max 5,000),
`desired_action` (max 255), and `channels: []`, a subset of
`facebook | instagram | linkedin | x | tiktok`.

## Content items (`/campaigns/:campaign_id/content_items`)
| Method | Path | Body |
| --- | --- | --- |
| POST | `/` | `{ content_item: { title, content_type } }` |
| PATCH | `/:id` | same |
| DELETE | `/:id` | hard delete (and its variants) |
| POST | `/:id/transition` | `{ status }` |

`content_type`: `post | image | video | carousel | story`. All writes return `422` when the
campaign is `completed` or `archived`.

## Variants (`/campaigns/:campaign_id/content_items/:content_item_id/variants`)
| Method | Path | Body |
| --- | --- | --- |
| POST | `/` | `{ variant: { platform, body, call_to_action, hashtags: [] } }` |
| PATCH | `/:id` | same |
| DELETE | `/:id` | hard delete |
| POST | `/:id/transition` | `{ status }` |

`platform`: `facebook | instagram | linkedin | x | tiktok` (labels only; no integration).
One variant per platform per content item. Hashtags: max 30, letters/digits/underscore,
stored without `#`, de-duplicated.

## AI generations (Phase 04)
| Method | Path | Body | Notes |
| --- | --- | --- | --- |
| GET | `/campaigns/:campaign_id/generations` | – | `{ payload: [generation] }`, 20 most recent |
| POST | `/campaigns/:campaign_id/generations` | `{ generation: { kind, content_item_id, content_variant_id, count, instruction, platforms: [] } }` | `202` with the queued generation. `422 { error }` when AI is not configured, the campaign is locked, the target is missing/approved/from another campaign, the instruction is missing or > 500 chars, or the same target is already running |
| GET | `/generations/:id` | – | Poll status; scoped to `Current.account` |

`kind`: `strategy | content_plan | content_item | variants | rewrite | suggestions`.
`variants` needs `content_item_id`; `rewrite`/`suggestions` need `content_variant_id`.
Generation fields: `id, campaign_id, content_item_id, content_variant_id, kind, status
(queued|generating|completed|failed), options, result, error_code, error_message, provider, model,
input_tokens, output_tokens, requested_by_id, started_at, completed_at, created_at, updated_at`.
Prompts are never returned or stored. Campaigns now include `strategy`; content items and variants
include `generation_id`. The shell includes `ai_configured`. Details: [ai-layer.md](ai-layer.md).

## Lifecycle
| Record | Transitions |
| --- | --- |
| Campaign | draft→active/archived · active→paused/completed · paused→active/completed/archived · completed→archived |
| Content item | draft→ready/archived · ready→draft/archived |
| Variant | draft→ready · ready→draft |
