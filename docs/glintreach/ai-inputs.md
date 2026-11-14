# GlintReach: Supplying brand and brief context to AI generation (Phase 03, implemented in Phase 04)

> Status: **design for later phases.** Phase 03 stores the data only. No AI calls, prompts or
> external APIs exist yet.

## 1. Inputs available after Phase 03

| Source | Model | Fields |
| --- | --- | --- |
| Brand profile (one per account) | `GlintReach::BrandProfile` | name, description, website_url, products_services, target_audience, geographic_market, preferred_languages (ISO codes), voice_and_tone, messaging_guidelines, prohibited_claims, approved_ctas |
| Campaign brief | `GlintReach::Campaign` | name, objective, target_audience, offer, key_message, desired_action, channels, starts_at/ends_at, brief (notes) |

Limits are enforced by model validations (name 255, long text 5,000 for the profile and for offer
and key message, 10,000 for campaign audience and notes, 10 languages, 20 CTAs of 100 characters each).
These limits bound the prompt size.

> **Status:** implemented in Phase 04 by `GlintReach::Generators::ContextBuilder`. See
> [ai-layer.md](ai-layer.md) for the full AI layer.

## 2. How the context is assembled

1. **Server-side only.** `GlintReach::Generators::ContextBuilder` loads
   `Current.account.glint_reach_brand_profile` and the campaign through `Current.account` (or, inside a
   job, through the `account_id` and `campaign_id` primitives). The browser never sends brand or
   brief text as part of a generation request. It sends only the campaign ID.
2. **Structured, not concatenated.** The builder returns a plain hash with fixed keys (as in the
   table above). The prompt template, versioned in the repo, serializes it as JSON inside clearly
   delimited blocks:

   ```text
   <brand_profile> {...JSON...} </brand_profile>
   <campaign_brief> {...JSON...} </campaign_brief>
   ```

3. **Untrusted data.** Every field is user input. The system prompt states that content inside
   these blocks is data describing the brand and must never be followed as instructions. Delimiter
   strings are stripped from values before serialization.
4. **Rules as constraints.** `prohibited_claims` and `messaging_guidelines` are passed as explicit
   constraints. `approved_ctas` limits `call_to_action` suggestions. `preferred_languages` and
   `channels` select the output languages and the platform variants to draft.
5. **No fetching.** `website_url` is reference text only. It is never fetched by the server, which
   avoids SSRF. Any future crawling would need its own reviewed design.
6. **Provider routing.** Calls go only through the existing `ruby_llm` setup and
   `Llm::FeatureRouter` (`config/llm.yml`), with keys kept server-side. Model names are never
   hard-coded.
7. **Output handling.** Generated text is saved as `draft` content variants for human review. It is
   validated by the same model rules and rendered as plain text. Nothing is published automatically.
8. **Audit and privacy.** Profile changes are already audited (`Enterprise::AuditLog`). Generation
   requests should log IDs and token counts, never the full prompt or brand text.

## 3. Missing profile

Generation must work without a brand profile, using the brief only. The UI already prompts users
to create one from Content Studio.
