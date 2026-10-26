# GlintReach Implementation Roadmap

Proposed phases. Each phase requires approval before starting. Phase names and order are a
recommendation and should be reconciled with the official GlintReach phase briefs.

| Phase | Scope | Depends on |
| --- | --- | --- |
| 00 | Repository audit, architecture and roadmap docs (this) | – |
| 01 | Foundation: `glint_reach` feature flag (`feature_flags_ext_1`), empty namespaced API base controller + policy, feature-gated dashboard route/sidebar entry, i18n, specs | 00, working dev env |
| 02 | Brand profile + campaign core models/migrations, CRUD API, policies, Jbuilder, UI list/detail | 01 |
| 03 | Content items/variants, approval workflow, Active Storage media | 02 |
| 04 | AI generation via `ruby_llm` / `Llm::FeatureRouter`, async jobs, usage limits | 03, AI provider decision |
| 05 | Social connections (OAuth, encrypted tokens) for first approved provider | 02, provider app access |
| 06 | Scheduling + publishing jobs (sidekiq-cron sweep, idempotent publish attempts) | 03, 05 |
| 07 | Attribution: tracked links/UTM, linking inbound conversations/contacts | 06 |
| 08 | Analytics/reporting from real recorded events | 07 |
| 09 | Hardening: audit logs, rate limits, docs, QA, release | all |

## Decisions (unresolved)

1. **Dev environment** – install Ruby 3.4.4 (rbenv), Node 24 + pnpm 10, run PostgreSQL 16 (+pgvector)
   and Redis, or use `docker-compose.yaml`. *Recommended:* install locally per `AGENTS.md`, then
   record a full baseline before Phase 01.
2. **Namespace** – *Recommended:* `GlintReach` (avoids the existing Chatwoot `Campaign` domain).
3. **Relationship to existing Chatwoot campaigns** – keep separate (recommended) vs. extend.
4. **OSS vs `enterprise/` placement** – *Recommended:* OSS tree, unless licensing is cleared.
5. **Roles** – administrator-only initially (like `CampaignPolicy`) vs. agents with custom roles.
6. **AI provider/models** – which provider and keys; must follow `config/llm.yml` and the OpenAI
   deprecation rule.
7. **Social providers** – which networks first; requires verified developer apps and review approval.
8. **Encryption** – Active Record encryption keys must be configured in all environments for token
   storage (`Chatwoot.encryption_configured?`).
9. **Branching/upstream sync** – feature branches off `develop`; cadence for merging upstream releases.

## Recommended next step
Resolve decision 1 (toolchain), record a passing/failing baseline for `rspec`, `rubocop`,
`pnpm test` and `pnpm eslint`, then start Phase 01.
