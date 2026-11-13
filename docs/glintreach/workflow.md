# GlintReach review, approval and scheduling (Phase 06)

Applies to **content variants** (one platform version of a content item), the unit that will be published.

## Lifecycle

| Status | Meaning | Content editable | Next |
| --- | --- | --- | --- |
| `draft` | Being written | yes | `in_review` |
| `in_review` | Waiting for a reviewer | no | `approved`, `changes_requested`, `draft` (withdraw) |
| `changes_requested` | Reviewer asked for changes | yes | `in_review` |
| `approved` | Approved exactly as it is | no | `scheduled`, `draft` (reopen voids the approval) |
| `scheduled` | Has a pending schedule | no | `approved` (cancel), `publishing` (dispatcher) |
| `publishing` | Dispatcher is handling it | no | `published`, `failed` |
| `failed` | Dispatch failed; error stored on the schedule | no | `scheduled` (reschedule with the same approval), `draft` |
| `published` | Reserved for the publishing phase | no | – |

- The transition table lives in `GlintReach::ContentVariant::TRANSITIONS`. All user actions go through `GlintReach::Workflow`, which locks the variant row, checks `lock_version` (409 if stale), the transition table and the role rules. Only the dispatch jobs move `scheduled → publishing → failed`.
- Content (body, CTA, hashtags, assets) can change only in `draft` / `changes_requested`. This is enforced in the model, the variant-assets endpoint and the AI generators.
- Migration note: former `ready` variants (integer 1) became `in_review`. They need a real approval; nothing was inferred.

## Approvals
- `glint_reach_approvals`: reviewer, decision (`approved` / `changes_requested`), feedback (required for changes, max 2,000), timestamp, and `content_digest`, a SHA-256 of body, CTA, hashtags and ordered asset IDs. Append-only and audited.
- Scheduling and dispatch both require the **latest** decision to be an approval whose digest matches the current content.

## Roles
GlintReach is limited to account administrators (`GlintReachPolicy`).

| Action | Who |
| --- | --- |
| Submit, withdraw, reopen, schedule, reschedule, cancel | Any administrator |
| Approve / request changes | An administrator **other than the submitter** (no self-approval) |

The API returns `permissions` on each variant for the UI, and the server re-checks every action.

## Scheduling and time zones
- Input is a wall-clock `date` (YYYY-MM-DD), a `time` (HH:MM, 24-hour) and an explicit IANA `timezone`. The default in the UI is the account reporting time zone, otherwise the browser's. `GlintReach::Workflow::ScheduleTime` converts it to UTC:
  - times skipped by DST ("spring forward") are rejected;
  - repeated times ("fall back") resolve to the **first** occurrence;
  - the time must be at least 5 minutes ahead, at most 1 year ahead, and inside the campaign dates when set.
- `glint_reach_schedules` stores `scheduled_at` (UTC), the chosen `timezone` (for display), status (`pending | dispatching | dispatched | cancelled | failed`), attempts and errors. A **partial unique index** allows only one pending/dispatching schedule per variant.
- Reschedule and cancel are allowed only while the schedule is `pending`. Once dispatching starts they return 409. Cancel is allowed even if the campaign has since been completed or archived.

## Dispatch
- `GlintReach::DispatchDueSchedulesJob` runs **every minute from sidekiq-cron** (`config/schedule.yml`, `scheduled_jobs` queue). It doesn't depend on a browser, and because the state is in Postgres it survives restarts.
  - It claims due rows with `FOR UPDATE SKIP LOCKED`, sets them to `dispatching` and enqueues one `GlintReach::PublishScheduledJob` per row.
  - Rows stuck in `dispatching` for more than 15 minutes return to `pending`, up to 3 attempts, and then fail with `dispatch_timeout`.
- `GlintReach::PublishScheduledJob` is idempotent: it acts only while the schedule is `dispatching` and the variant is `scheduled`. It locks the variant and then the schedule (the same order as cancel), then revalidates:
  1. the `glint_reach` flag;
  2. the campaign is `active`;
  3. the approval is current and its digest matches;
  4. a publisher is available for the platform.
- **No publishers exist in this phase**, so step 4 always records `publisher_unavailable` ("Publishing to social networks is not available yet"). The variant becomes `failed` and **no external request is made**. The publishing phase adds publishers to `GlintReach::Publishers::REGISTRY`.

## UI
- **Content Studio variant card:** status, workflow buttons (submit, review with approve / request changes and feedback, withdraw, schedule/reschedule dialog with time zone, cancel, reopen), the schedule time in its zone, reviewer feedback and error messages.
- **Calendar module:** month/week/day calendar, a list, and the approval queue, with status filters and a time-zone selector. Built with `date-fns` / `date-fns-tz` (no new dependency). Day placement uses the selected zone, never the browser's.
