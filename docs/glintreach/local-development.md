# GlintReach – Local Development

GlintReach is behind the account feature flag `glint_reach` (disabled by default) and is
visible only to **administrators** of an account where the flag is enabled.

## Prerequisites
Standard Chatwoot setup (see `AGENTS.md`): Ruby from `.ruby-version` via rbenv, Node 24,
pnpm 10, PostgreSQL 16 (+pgvector), Redis.

```bash
eval "$(rbenv init -)"
bundle install && pnpm install
bundle exec rails db:prepare && bundle exec rails db:seed
pnpm dev
```

## Enable GlintReach for an account
Only an installation operator (Super Admin or console access) can do this.

**Super Admin UI:** `/super_admin` → Accounts → select the account → Edit → enable **GlintReach**.

**Rails console:**
```ruby
Account.find(<account_id>).enable_features!('glint_reach')
# disable again
Account.find(<account_id>).disable_features!('glint_reach')
```

Then reload the dashboard as an administrator of that account: the **GlintReach** group appears
in the sidebar after Campaigns, at `/app/accounts/<account_id>/glint-reach/overview`.

## Access rules
| Check | Frontend | API (`GET /api/v1/accounts/:account_id/glint_reach/shell`) |
| --- | --- | --- |
| Not a member of the account | Redirected by the existing router guard | 401 |
| Agent (not administrator) | Hidden in sidebar; route redirects | 401 |
| Flag disabled | Hidden in sidebar; typed URL shows "not enabled" | 403 |
| Administrator + flag enabled | Shell visible | 200 |

## Tests
```bash
bundle exec rspec spec/controllers/api/v1/accounts/glint_reach spec/policies/glint_reach_policy_spec.rb
pnpm test app/javascript/dashboard/routes/dashboard/glintReach
```
