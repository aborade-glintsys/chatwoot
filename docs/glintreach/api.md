# GlintReach API (Phase 02)

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

## Lifecycle
| Record | Transitions |
| --- | --- |
| Campaign | draft→active/archived · active→paused/completed · paused→active/completed/archived · completed→archived |
| Content item | draft→ready/archived · ready→draft/archived |
| Variant | draft→ready · ready→draft |
