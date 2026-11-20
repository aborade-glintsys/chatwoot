# GlintReach Social Providers & OAuth (Phase 07)

## 1. Platform research and decision record

*Official developer documentation reviewed on 2026-11-20. Platform policies, scopes and pricing change frequently — re-verify before submitting an app for production review.*

| Platform | Required posting scopes | External approval for customer use | Account eligibility | Key limitations |
| --- | --- | --- | --- | --- |
| **LinkedIn (Member profile)** | `openid`, `profile`, `email` (*Sign In with LinkedIn using OpenID Connect*) + `w_member_social` (*Share on LinkedIn*) | **None.** Both products are self-serve and provisioned immediately in the LinkedIn Developer Portal. | Any LinkedIn member; posts to their **personal profile** (`urn:li:person:{sub}`). | Access tokens expire after ~60 days; self-serve apps do **not** receive refresh tokens (member must reconnect). ~150 member calls/day. |
| LinkedIn (Company Pages) | `w_organization_social`, `r_organization_admin` | **Community Management API** application (vetted business use case; weeks of review). | Page administrators. | Separate review track; out of scope for v1. |
| Meta — Facebook Pages | `pages_manage_posts`, `pages_show_list`, `pages_read_engagement` | Development mode works only for app-role users. Serving external customers requires **Meta App Review** and **Business Verification**. | Facebook Pages managed by the authorizing user. | Graph API rate limits. |
| Meta — Instagram (Instagram Login) | `instagram_business_basic`, `instagram_business_content_publish` | **Meta App Review** for Advanced Access (screencast, test credentials, prior dev API call). | **Professional** (Business or Creator) accounts only. | 50–100 API posts per rolling 24 hours per account; media must be reachable via public URL. |
| X (Twitter) | `tweet.write`, `tweet.read`, `users.read`, `offline.access` (OAuth 2.0 + PKCE) | Developer account + **prepaid pay-per-use credits** (free write tier discontinued for new apps). | Any X account. | Per-post charges (higher when a post includes a URL). |
| TikTok | `video.publish` (Content Posting API) | **Client Audit** required before public posting. Unaudited apps are restricted to `SELF_ONLY` private posts and 5 users/24h. | Creators. | Video-only direct post; strict UX/privacy-disclosure requirements. |

### Selected initial platform: LinkedIn (Member profile posting)

**Why LinkedIn first:**
1. **Audience fit:** GlintReach serves businesses already using Chatwoot (primarily B2B and SMB teams), where LinkedIn is a core organic channel.
2. **Feasibility without external gates:** LinkedIn's *Sign In with LinkedIn using OpenID Connect* + *Share on LinkedIn* is the only candidate that can be configured and tested end-to-end with real users without waiting on Meta App Review / Business Verification, TikTok Client Audit, or prepaid X API credits.
3. **Honest boundaries:**
   - Supports **personal LinkedIn profiles only** in v1. Company Pages require the vetted Community Management API and will be modeled as a separate capability/account type when approved.
   - Self-serve LinkedIn apps do **not** issue refresh tokens; tokens expire after ~60 days and surface as **Reconnect required**.
   - Capabilities in v1: **text** and **single-image** posts up to 3,000 characters (`JPEG`, `PNG`, `GIF`). Video, documents, carousels and native scheduling are not offered.
4. **Recommended second provider:** Meta (Facebook Pages & Instagram Business), leveraging Chatwoot's existing Meta app familiarity. Start Meta Business Verification and App Review early before Phase 08+.

---

## 2. Architecture

### Provider abstraction (`app/services/glint_reach/social/`)
- `Providers::Base` — provider-neutral contract:
  - `authorize_url(state:, code_challenge:, redirect_uri:)`
  - `exchange_code(code:, code_verifier:, redirect_uri:) -> TokenSet`
  - `refresh(token_set) -> TokenSet` (raises `Error::RefreshUnsupported` when unsupported)
  - `revoke(token_set)`
  - `fetch_identity(token_set) -> Identity`
  - `capabilities -> Capabilities`
  - `required_scopes`, `optional_scopes`, `configured?`, `approval_notes`
- `Providers::Linkedin` — first implementation (OIDC + Share on LinkedIn). All outbound HTTP goes through Faraday with explicit timeouts to fixed LinkedIn hosts (`www.linkedin.com`, `api.linkedin.com`).
- `Providers::REGISTRY` — maps provider key (`'linkedin'`) to provider class.
- `Capabilities` — immutable value object describing supported post types, text/image limits, allowed MIME types, video/native-scheduling/refresh support, and token lifetime. Returned by the API so the UI never offers unsupported actions.
- `OauthFlow` — orchestrates `start` (creates server-side single-use `GlintReach::OauthState` with PKCE + browser-binding nonce) and `complete` (validates state, cookie nonce, expiry, single-use consumption under row lock, admin/feature-flag re-check, code exchange, ID token claim checks, scope verification, and account upsert).

### Data model
- `glint_reach_social_accounts`:
  - Scoped to `account_id` with `connected_by_id`, `provider`, `provider_account_id`, `provider_account_type`, `display_name`, `profile_url`, `avatar_url`, `granted_scopes`, `token_expires_at`, `refresh_expires_at`, `status` (`connected`, `expired`, `revoked`, `missing_scopes`, `error`), `last_error_code`, `last_error_message`, `last_verified_at`.
  - Unique on `(account_id, provider, provider_account_id)`. The same LinkedIn member may connect to different Chatwoot accounts as completely independent rows with separate tokens.
  - `access_token` and `refresh_token` use **Active Record Encryption** (`encrypts`). Tokens are **never** serialized in JSON, logged, or stored in audit logs.
  - Encryption is **mandatory**: if `Chatwoot.encryption_configured?` is false, connecting is disabled and the model refuses to persist any token.
- `glint_reach_oauth_states`:
  - `state_digest` (SHA-256 of the random 32-byte state token), `browser_nonce_digest` (SHA-256 of the HttpOnly cookie nonce), `account_id`, `user_id`, `provider`, encrypted `code_verifier`, `expires_at` (10 minutes), `consumed_at`.
  - Single-use: consumed atomically under a row lock on callback.

### Security controls
- **CSRF & login-CSRF protection:** state token is verified server-side AND bound to an `HttpOnly`, `SameSite=Lax` (`Secure` in HTTPS) cookie set when the admin clicks Connect. Opening someone else's callback URL in another browser fails with `invalid_state`.
- **Redirect URI validation:** always constructed server-side from `ENV['FRONTEND_URL']` (`/glint_reach/oauth/:provider/callback`). Request host headers and query parameters are never used.
- **No reflected provider errors:** provider `error` / `error_description` parameters are mapped to internal status codes before redirecting back to the dashboard.
- **Credential hygiene:** `access_token`, `refresh_token`, and `code_verifier` are excluded from serializers, Rails parameter logs (`filter_parameters`), and Enterprise audit logs.
- **Token lifecycle:** `GlintReach::VerifySocialAccountsJob` (daily via `sidekiq-cron`) marks expired connections and verifies active tokens with the provider's userinfo endpoint, marking 401s as `revoked`.

---

## 3. Setup and configuration

### Required environment variables (Active Record Encryption)
GlintReach will not store OAuth tokens without encryption. Generate keys with `bundle exec rails db:encryption:init` and set:
- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`
- `FRONTEND_URL` — public origin of your Chatwoot instance (e.g. `https://app.example.com`).

### LinkedIn Developer App setup
1. Create an app at https://www.linkedin.com/developers/apps and associate it with a LinkedIn Page (LinkedIn requires a Page to create any app, even for member-only posting).
2. Under **Products**, request (self-serve, instant):
   - **Sign In with LinkedIn using OpenID Connect**
   - **Share on LinkedIn**
3. Under **Auth → OAuth 2.0 settings → Authorized redirect URLs for your app**, add:
   ```text
   {FRONTEND_URL}/glint_reach/oauth/linkedin/callback
   ```
   (For local development: `http://localhost:3000/glint_reach/oauth/linkedin/callback`.)
4. Copy the **Client ID** and **Client Secret** into Chatwoot **Super Admin → Installation Config**:
   - `GLINT_REACH_LINKEDIN_CLIENT_ID`
   - `GLINT_REACH_LINKEDIN_CLIENT_SECRET` (stored as secret type; never commit real values to git).

### External approvals for future providers
- **LinkedIn Company Pages:** apply for *Community Management API* in the LinkedIn Developer Portal.
- **Facebook Pages / Instagram Business:** complete Meta Business Verification and submit `pages_manage_posts` / `instagram_business_content_publish` for Meta App Review with screencasts and test accounts.
- **X:** fund a prepaid API credit balance in the X Developer Console.
- **TikTok:** complete the Content Posting API Client Audit before enabling public posting.

---

## 4. Verification status

- **Automated tests (stubbed LinkedIn HTTP endpoints via WebMock):** cover OAuth start, callback success, invalid/expired/reused state, cookie mismatch, provider `access_denied`, token-exchange failures, ID-token claim validation, missing `w_member_social` scope, token encryption at rest (with Active Record Encryption enabled), token absence from API responses and audits, expiry/revocation verification job, disconnect + revoke failure resilience, and cross-account isolation.
- **Live LinkedIn OAuth verification:** **BLOCKED** in this environment because no real LinkedIn developer app credentials (`GLINT_REACH_LINKEDIN_CLIENT_ID` / `GLINT_REACH_LINKEDIN_CLIENT_SECRET`) or local encryption keys are configured. Do not treat live LinkedIn connectivity as verified until tested end-to-end against a real LinkedIn developer app using the manual QA checklist in the Phase 07 completion report.
