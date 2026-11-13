require 'rails_helper'

RSpec.describe 'GlintReach variant workflow API', type: :request do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account, role: :administrator) }
  let(:reviewer) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:campaign) { create(:glint_reach_campaign, account: account, created_by: author) }
  let(:item) { create(:glint_reach_content_item, campaign: campaign) }
  let(:variant) { create(:glint_reach_content_variant, content_item: item, body: 'Launch day') }
  let(:base) { "/api/v1/accounts/#{account.id}/glint_reach/campaigns/#{campaign.id}/content_items/#{item.id}/variants/#{variant.id}" }
  let(:at) { 2.days.from_now.utc }

  before { account.enable_features!(:glint_reach) }

  def act(action, user, params = {})
    post "#{base}/#{action}", params: params, headers: user.create_new_auth_token, as: :json
  end

  it 'runs submit -> approve -> schedule -> cancel end to end' do
    act(:submit, author)
    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'in_review', 'submitted_by_id' => author.id)

    act(:review, reviewer, decision: 'approved', feedback: 'Ship it')
    expect(response.parsed_body['status']).to eq('approved')
    expect(response.parsed_body['latest_approval']).to include('decision' => 'approved', 'feedback' => 'Ship it')

    act(:schedule, author, date: at.to_date.iso8601, time: '10:15', timezone: 'Europe/Berlin')
    body = response.parsed_body
    expect(body['status']).to eq('scheduled')
    expect(body['schedule']).to include('status' => 'pending', 'timezone' => 'Europe/Berlin')
    expect(Time.zone.at(body['schedule']['scheduled_at'])).to eq(ActiveSupport::TimeZone['Europe/Berlin'].parse("#{at.to_date} 10:15"))
  end

  it 'cancels a schedule and lists approval history' do
    act(:submit, author)
    act(:review, reviewer, decision: 'approved')
    act(:schedule, author, date: at.to_date.iso8601, time: '10:15', timezone: 'UTC')
    act(:cancel_schedule, author)
    expect(response.parsed_body['status']).to eq('approved')

    get "#{base}/approvals", headers: author.create_new_auth_token
    expect(response.parsed_body['payload'].first).to include('decision' => 'approved')
  end

  it 'returns 403 for self-approval' do
    act(:submit, author)
    act(:review, author, decision: 'approved')
    expect(response).to have_http_status(:forbidden)
    expect(variant.reload).to be_in_review
  end

  it 'returns 409 for invalid transitions and stale lock versions' do
    act(:schedule, author, date: at.to_date.iso8601, time: '10:00', timezone: 'UTC')
    expect(response).to have_http_status(:conflict)

    act(:submit, author, lock_version: variant.lock_version + 5)
    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['error']).to include('someone else')
  end

  it 'returns 409 with a clear message for a DST gap' do
    act(:submit, author)
    act(:review, reviewer, decision: 'approved')
    travel_to(Time.utc(2026, 2, 1)) do
      act(:schedule, author, date: '2026-03-08', time: '02:30', timezone: 'America/New_York')
    end
    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['error']).to include('does not exist')
  end

  it 'blocks editing content while in review' do
    act(:submit, author)
    patch base, params: { variant: { body: 'Changed' } }, headers: author.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(variant.reload.body).to eq('Launch day')
  end

  it 'blocks deleting a scheduled variant' do
    act(:submit, author)
    act(:review, reviewer, decision: 'approved')
    act(:schedule, author, date: at.to_date.iso8601, time: '10:00', timezone: 'UTC')
    delete base, headers: author.create_new_auth_token, as: :json
    expect(response).to have_http_status(:conflict)
  end

  it 'exposes permissions for the current user' do
    act(:submit, author)
    expect(response.parsed_body['permissions']).to include('review' => false, 'withdraw' => true)
    act(:withdraw, reviewer)
    expect(response.parsed_body['status']).to eq('draft')
  end

  it 'denies agents, disabled accounts and other accounts' do
    act(:submit, agent)
    expect(response).to have_http_status(:unauthorized)

    outsider = create(:user, account: create(:account), role: :administrator)
    act(:submit, outsider)
    expect(response).to have_http_status(:unauthorized)

    other_variant = create(:glint_reach_content_variant)
    post "/api/v1/accounts/#{account.id}/glint_reach/campaigns/#{campaign.id}/content_items/#{item.id}/variants/#{other_variant.id}/submit",
         headers: author.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)

    account.disable_features!(:glint_reach)
    act(:submit, author)
    expect(response).to have_http_status(:forbidden)
  end
end
