require 'rails_helper'

RSpec.describe 'GlintReach calendar and approvals API', type: :request do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account, role: :administrator) }
  let(:reviewer) { create(:user, account: account, role: :administrator) }
  let(:campaign) { create(:glint_reach_campaign, account: account, created_by: author, name: 'Spring') }
  let(:headers) { author.create_new_auth_token }
  let(:calendar_path) { "/api/v1/accounts/#{account.id}/glint_reach/calendar" }

  before { account.enable_features!(:glint_reach) }

  def scheduled_at(utc, target_campaign = campaign)
    item = create(:glint_reach_content_item, campaign: target_campaign)
    variant = create(:glint_reach_content_variant, content_item: item, body: 'Post')
    approval = GlintReach::Approval.create!(content_variant: variant, reviewer: reviewer, decision: :approved,
                                            content_digest: variant.content_digest)
    variant.update_columns(status: GlintReach::ContentVariant.statuses[:scheduled]) # rubocop:disable Rails/SkipsModelValidations
    GlintReach::Schedule.create!(content_variant: variant, approval: approval, scheduled_by: author, scheduled_at: utc, timezone: 'UTC')
  end

  it 'returns schedules inside the day range of the requested timezone' do
    # 2026-05-10 23:30 UTC is 2026-05-11 05:00 in Kolkata.
    late = scheduled_at(Time.utc(2026, 5, 10, 23, 30))

    get calendar_path, params: { from: '2026-05-11', to: '2026-05-11', timezone: 'Asia/Kolkata' }, headers: headers
    expect(response.parsed_body['payload'].pluck('id')).to eq([late.id])
    expect(response.parsed_body['payload'].first).to include('campaign' => hash_including('name' => 'Spring'))

    get calendar_path, params: { from: '2026-05-11', to: '2026-05-11', timezone: 'UTC' }, headers: headers
    expect(response.parsed_body['payload']).to be_empty
  end

  it 'filters by status and excludes cancelled and other accounts' do
    pending = scheduled_at(Time.utc(2026, 5, 12, 10))
    cancelled = scheduled_at(Time.utc(2026, 5, 12, 11))
    cancelled.update!(status: :cancelled)
    scheduled_at(Time.utc(2026, 5, 12, 12), create(:glint_reach_campaign))

    get calendar_path, params: { from: '2026-05-01', to: '2026-05-31' }, headers: headers
    expect(response.parsed_body['payload'].pluck('id')).to eq([pending.id])

    get calendar_path, params: { from: '2026-05-01', to: '2026-05-31', status: ['failed'] }, headers: headers
    expect(response.parsed_body['payload']).to be_empty
  end

  it 'validates the range and timezone' do
    get calendar_path, params: { from: '2026-05-01', to: '2026-08-01' }, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
    get calendar_path, params: { from: '2026-05-02', to: '2026-05-01' }, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
    get calendar_path, params: { from: '2026-05-01', to: '2026-05-02', timezone: 'Nowhere/City' }, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'lists the approval queue oldest first, scoped to the account' do
    item = create(:glint_reach_content_item, campaign: campaign)
    first = create(:glint_reach_content_variant, content_item: item, platform: :instagram, body: 'A')
    second = create(:glint_reach_content_variant, content_item: item, platform: :x, body: 'B')
    GlintReach::Workflow.new(variant: second, user: author).submit!
    travel(-1.hour) { GlintReach::Workflow.new(variant: first, user: author).submit! }
    other = create(:glint_reach_content_variant, body: 'C')
    other.update_columns(status: 1) # rubocop:disable Rails/SkipsModelValidations

    get "/api/v1/accounts/#{account.id}/glint_reach/approvals", headers: reviewer.create_new_auth_token
    payload = response.parsed_body['payload']
    expect(payload.pluck('id')).to eq([first.id, second.id])
    expect(payload.first).to include('campaign' => hash_including('name' => 'Spring'), 'permissions' => hash_including('review' => true))
    expect(response.parsed_body['meta']['count']).to eq(2)
  end
end
