require 'rails_helper'

RSpec.describe GlintReach::PublishScheduledJob do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account, role: :administrator) }
  let(:reviewer) { create(:user, account: account, role: :administrator) }
  let(:campaign) { create(:glint_reach_campaign, account: account, created_by: author, status: :active) }
  let(:variant) do
    item = create(:glint_reach_content_item, campaign: campaign)
    create(:glint_reach_content_variant, content_item: item, body: 'Post')
  end
  let(:schedule) do
    GlintReach::Workflow.new(variant: variant, user: author).submit!
    GlintReach::Workflow.new(variant: variant, user: reviewer).review!(decision: 'approved')
    at = 1.hour.from_now.utc
    GlintReach::Workflow.new(variant: variant, user: author).schedule!(date: at.to_date.iso8601, time: at.strftime('%H:%M'), timezone: 'UTC')
    variant.schedules.sole.tap { |record| record.update!(status: :dispatching, dispatch_started_at: Time.current, attempts: 1) }
  end

  before { account.enable_features!(:glint_reach) }

  it 'publishes nothing in this phase and records publisher_unavailable' do
    described_class.perform_now(schedule.id)

    expect(schedule.reload).to have_attributes(status: 'failed', error_code: 'publisher_unavailable')
    expect(schedule.error_message).to include('not available yet')
    expect(variant.reload).to be_failed
    expect(a_request(:any, /.*/)).not_to have_been_made
  end

  it 'is a no-op when run twice or after cancellation' do
    described_class.perform_now(schedule.id)
    expect { described_class.perform_now(schedule.id) }.not_to(change { schedule.reload.attributes })

    expect { described_class.perform_now(0) }.not_to raise_error
  end

  it 'does nothing for a schedule that is not dispatching' do
    schedule.update!(status: :pending)
    described_class.perform_now(schedule.id)
    expect(schedule.reload).to be_pending
    expect(variant.reload).to be_scheduled
  end

  it 'revalidates the approval digest before dispatch' do
    schedule
    GlintReach::ContentVariant.where(id: variant.id).update_all(body: 'Changed after approval') # rubocop:disable Rails/SkipsModelValidations
    described_class.perform_now(schedule.id)
    expect(schedule.reload.error_code).to eq('approval_invalid')
  end

  it 'revalidates that the campaign is active' do
    schedule
    campaign.update_columns(status: GlintReach::Campaign.statuses[:paused]) # rubocop:disable Rails/SkipsModelValidations
    described_class.perform_now(schedule.id)
    expect(schedule.reload.error_code).to eq('campaign_not_active')
  end

  it 'revalidates the feature flag' do
    schedule
    account.disable_features!(:glint_reach)
    described_class.perform_now(schedule.id)
    expect(schedule.reload.error_code).to eq('glint_reach_disabled')
  end

  it 'lets a failed variant be rescheduled with the same approval' do
    described_class.perform_now(schedule.id)
    at = 2.hours.from_now.utc
    GlintReach::Workflow.new(variant: variant.reload, user: author)
                        .schedule!(date: at.to_date.iso8601, time: at.strftime('%H:%M'), timezone: 'UTC')
    expect(variant.reload).to be_scheduled
    expect(variant.schedules.live.count).to eq(1)
  end
end
