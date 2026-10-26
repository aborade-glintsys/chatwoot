require 'rails_helper'

RSpec.describe 'GlintReach Campaigns API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_account) { create(:account) }
  let(:base_path) { "/api/v1/accounts/#{account.id}/glint_reach/campaigns" }
  let(:valid_params) { { campaign: { name: 'Spring launch', objective: 'awareness', brief: 'New collection', target_audience: 'Returning buyers' } } }

  before do
    account.enable_features!(:glint_reach)
    other_account.enable_features!(:glint_reach)
  end

  def create_campaign(**attrs)
    create(:glint_reach_campaign, account: account, created_by: admin, **attrs)
  end

  describe 'access control' do
    it 'returns unauthorized when unauthenticated' do
      get base_path

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized for an agent' do
      get base_path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns forbidden when GlintReach is disabled' do
      account.disable_features!(:glint_reach)

      post base_path, params: valid_params, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(GlintReach::Campaign.count).to eq(0)
    end

    it 'returns unauthorized for an administrator of another account' do
      outsider = create(:user, account: other_account, role: :administrator)

      get base_path, headers: outsider.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /campaigns' do
    it 'lists only campaigns of the current account, excluding archived by default' do
      visible = create_campaign(name: 'Visible')
      create_campaign(name: 'Old', status: :archived)
      create(:glint_reach_campaign, account: other_account)

      get base_path, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('id')).to eq([visible.id])
      expect(response.parsed_body['meta']).to eq('count' => 1, 'current_page' => 1)
    end

    it 'filters by status and search term' do
      archived = create_campaign(name: 'Winter promo', status: :archived)
      create_campaign(name: 'Winter launch')

      get base_path, params: { status: 'archived', search: 'winter' }, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to eq([archived.id])
    end

    it 'paginates 25 per page' do
      create_list(:glint_reach_campaign, 26, account: account, created_by: admin)

      get base_path, params: { page: 2 }, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload'].size).to eq(1)
      expect(response.parsed_body['meta']).to eq('count' => 26, 'current_page' => 2)
    end

    it 'rejects an unknown status filter' do
      get base_path, params: { status: 'deleted' }, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST /campaigns' do
    it 'creates a draft campaign owned by the current account and user' do
      post base_path, params: valid_params, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      campaign = GlintReach::Campaign.last
      expect(campaign).to have_attributes(account_id: account.id, created_by_id: admin.id, status: 'draft', name: 'Spring launch')
      expect(response.parsed_body['created_by']['id']).to eq(admin.id)
    end

    it 'ignores client-supplied account, creator and status' do
      params = valid_params.deep_merge(campaign: { account_id: other_account.id, created_by_id: agent.id, status: 'active' })

      post base_path, params: params, headers: admin.create_new_auth_token, as: :json

      expect(GlintReach::Campaign.last).to have_attributes(account_id: account.id, created_by_id: admin.id, status: 'draft')
    end

    it 'returns 422 for invalid input' do
      post base_path, params: { campaign: { name: '', objective: 'fame' } }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['attributes']).to include('name', 'objective')
    end

    it 'returns 422 when the campaign param is missing' do
      post base_path, params: {}, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /campaigns/:id' do
    it 'returns the campaign with content items and variants' do
      campaign = create_campaign
      item = create(:glint_reach_content_item, campaign: campaign)
      create(:glint_reach_content_variant, content_item: item, platform: :facebook)

      get "#{base_path}/#{campaign.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['content_items'].first['variants'].first['platform']).to eq('facebook')
    end

    it 'returns 404 for a missing campaign' do
      get "#{base_path}/0", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for a campaign of another account' do
      foreign = create(:glint_reach_campaign, account: other_account)

      get "#{base_path}/#{foreign.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /campaigns/:id' do
    it 'updates permitted attributes but not status' do
      campaign = create_campaign

      patch "#{base_path}/#{campaign.id}", params: { campaign: { name: 'Renamed', status: 'completed' } },
                                           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(campaign.reload).to have_attributes(name: 'Renamed', status: 'draft')
    end

    it 'rejects edits to a completed campaign' do
      campaign = create_campaign(status: :completed)

      patch "#{base_path}/#{campaign.id}", params: { campaign: { name: 'Renamed' } }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(campaign.reload.name).not_to eq('Renamed')
    end

    it 'cannot update a campaign of another account' do
      foreign = create(:glint_reach_campaign, account: other_account, name: 'Theirs')

      patch "#{base_path}/#{foreign.id}", params: { campaign: { name: 'Mine' } }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.name).to eq('Theirs')
    end
  end

  describe 'DELETE /campaigns/:id' do
    it 'archives instead of deleting' do
      campaign = create_campaign

      delete "#{base_path}/#{campaign.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(campaign.reload).to be_archived
    end

    it 'rejects archiving an active campaign' do
      campaign = create_campaign(status: :active)

      delete "#{base_path}/#{campaign.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(campaign.reload).to be_active
    end
  end

  describe 'POST /campaigns/:id/transition' do
    it 'applies an allowed transition' do
      campaign = create_campaign

      post "#{base_path}/#{campaign.id}/transition", params: { status: 'active' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(campaign.reload).to be_active
    end

    it 'returns 422 for an invalid transition' do
      campaign = create_campaign

      post "#{base_path}/#{campaign.id}/transition", params: { status: 'completed' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to include('cannot change from draft to completed')
    end
  end
end
