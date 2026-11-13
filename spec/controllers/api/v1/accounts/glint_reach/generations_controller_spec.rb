require 'rails_helper'

RSpec.describe 'GlintReach Generations API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:campaign) { create(:glint_reach_campaign, account: account, created_by: admin) }
  let(:path) { "/api/v1/accounts/#{account.id}/glint_reach/campaigns/#{campaign.id}/generations" }
  let(:headers) { admin.create_new_auth_token }

  before do
    account.enable_features!(:glint_reach)
    allow(GlintReach::Ai::ProviderResolver).to receive(:configured?).and_return(true)
  end

  describe 'POST create' do
    it 'queues a generation and returns 202 without prompts' do
      expect do
        post path, params: { generation: { kind: 'strategy' } }, headers: headers, as: :json
      end.to have_enqueued_job(GlintReach::GenerationJob)

      expect(response).to have_http_status(:accepted)
      body = response.parsed_body
      expect(body).to include('kind' => 'strategy', 'status' => 'queued', 'campaign_id' => campaign.id)
      expect(body.keys).not_to include('system_prompt', 'user_content', 'prompt')
    end

    it 'returns 422 with an actionable message when AI is not configured' do
      allow(GlintReach::Ai::ProviderResolver).to receive(:configured?).and_return(false)
      post path, params: { generation: { kind: 'strategy' } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('not configured')
    end

    it 'returns 422 for content items from another account' do
      other_item = create(:glint_reach_content_item)
      post path, params: { generation: { kind: 'variants', content_item_id: other_item.id } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(GlintReach::Generation.count).to eq(0)
    end

    it 'returns 401 for agents' do
      post path, params: { generation: { kind: 'strategy' } }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 403 when GlintReach is disabled' do
      account.disable_features!(:glint_reach)
      post path, params: { generation: { kind: 'strategy' } }, headers: headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 404 for a campaign in another account' do
      other = create(:glint_reach_campaign)
      post "/api/v1/accounts/#{account.id}/glint_reach/campaigns/#{other.id}/generations",
           params: { generation: { kind: 'strategy' } }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET index and show' do
    let!(:generation) { campaign.generations.create!(requested_by: admin, kind: :strategy) }

    it 'lists recent generations for the campaign' do
      get path, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('id')).to eq([generation.id])
    end

    it 'shows a generation' do
      get "/api/v1/accounts/#{account.id}/glint_reach/generations/#{generation.id}", headers: headers, as: :json
      expect(response.parsed_body).to include('id' => generation.id, 'status' => 'queued')
    end

    it 'does not show generations from another account' do
      other_campaign = create(:glint_reach_campaign)
      other = other_campaign.generations.create!(requested_by: other_campaign.created_by, kind: :strategy)

      get "/api/v1/accounts/#{account.id}/glint_reach/generations/#{other.id}", headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
