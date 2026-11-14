require 'rails_helper'

RSpec.describe GlintReach::DispatchDueSchedulesJob do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account, role: :administrator) }
  let(:reviewer) { create(:user, account: account, role: :administrator) }
  let(:campaign) { create(:glint_reach_campaign, account: account, created_by: author, status: :active) }

  before { account.enable_features!(:glint_reach) }

  def scheduled_variant(at: 10.minutes.from_now, platform: :instagram)
    item = create(:glint_reach_content_item, campaign: campaign)
    variant = create(:glint_reach_content_variant, content_item: item, platform: platform, body: 'Post')
    GlintReach::Workflow.new(variant: variant, user: author).submit!
    GlintReach::Workflow.new(variant: variant, user: reviewer).review!(decision: 'approved')
    GlintReach::Workflow.new(variant: variant, user: author)
                        .schedule!(date: at.utc.to_date.iso8601, time: at.utc.strftime('%H:%M'), timezone: 'UTC')
    variant.reload
  end

  it 'claims only due pending schedules and enqueues one publish job each' do
    due = scheduled_variant
    future = scheduled_variant(at: 2.hours.from_now)

    travel 30.minutes do
      expect { described_class.perform_now }.to have_enqueued_job(GlintReach::PublishScheduledJob).exactly(:once)
    end
    expect(due.schedules.sole).to have_attributes(status: 'dispatching', attempts: 1)
    expect(future.schedules.sole).to be_pending
  end

  it 'does not claim a schedule twice when run again (duplicate cron execution)' do
    scheduled_variant
    travel 30.minutes do
      described_class.perform_now
      expect { described_class.perform_now }.not_to have_enqueued_job(GlintReach::PublishScheduledJob)
    end
  end

  it 'claims with FOR UPDATE SKIP LOCKED so concurrent dispatchers never take the same row' do
    scheduled_variant
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] }
    travel 30.minutes do
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { described_class.perform_now }
    end
    expect(queries.grep(/FROM "glint_reach_schedules".*FOR UPDATE SKIP LOCKED/m)).not_to be_empty
  end

  it 'never claims cancelled schedules' do
    variant = scheduled_variant
    GlintReach::Workflow.new(variant: variant, user: author).cancel_schedule!
    travel(30.minutes) { expect { described_class.perform_now }.not_to have_enqueued_job(GlintReach::PublishScheduledJob) }
  end

  it 'returns stale dispatching rows to pending, then fails them after max attempts' do
    variant = scheduled_variant
    schedule = variant.schedules.sole
    travel 30.minutes do
      described_class.perform_now
    end
    travel 50.minutes do
      described_class.perform_now # stale -> pending -> immediately reclaimed (attempt 2)
      expect(schedule.reload).to have_attributes(status: 'dispatching', attempts: 2)
    end
    schedule.update_columns(attempts: described_class::MAX_ATTEMPTS) # rubocop:disable Rails/SkipsModelValidations
    travel 70.minutes do
      described_class.perform_now
    end
    expect(schedule.reload).to have_attributes(status: 'failed', error_code: 'dispatch_timeout')
    expect(variant.reload).to be_failed
  end
end
