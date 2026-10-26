require 'rails_helper'

RSpec.describe 'GlintReach Brand Profile API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_account) { create(:account) }
  let(:path) { "/api/v1/accounts/#{account.id}/glint_reach/brand_profile" }
  let(:valid_params) do
    {
      brand_profile: {
        name: 'Acme Outdoors', description: 'Gear for hikers', website_url: 'https://acme.example',
        products_services: 'Tents, backpacks', target_audience: 'Weekend hikers', geographic_market: 'India',
        preferred_languages: %w[en hi], voice_and_tone: 'Friendly', messaging_guidelines: 'Be concrete',
        prohibited_claims: 'Lifetime warranty', approved_ctas: ['Shop now', 'Learn more']
      }
    }
  end

  before do
    account.enable_features!(:glint_reach)
    other_account.enable_features!(:glint_reach)
  end

  describe 'access control' do
    it 'returns unauthorized when unauthenticated' do
      get path

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized for an agent' do
      put path, params: valid_params, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(GlintReach::BrandProfile.count).to eq(0)
    end

    it 'returns forbidden when GlintReach is disabled' do
      account.disable_features!(:glint_reach)

      put path, params: valid_params, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(GlintReach::BrandProfile.count).to eq(0)
    end

    it 'returns unauthorized for an administrator of another account' do
      outsider = create(:user, account: other_account, role: :administrator)

      put path, params: valid_params, headers: outsider.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(GlintReach::BrandProfile.count).to eq(0)
    end
  end

  describe 'GET /brand_profile' do
    it 'returns null when the account has no profile' do
      create(:glint_reach_brand_profile, account: other_account)

      get path, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq('brand_profile' => nil)
    end

    it 'returns only the current account profile' do
      profile = create(:glint_reach_brand_profile, account: account, name: 'Mine')
      create(:glint_reach_brand_profile, account: other_account, name: 'Theirs')

      get path, headers: admin.create_new_auth_token, as: :json

      body = response.parsed_body['brand_profile']
      expect(body['id']).to eq(profile.id)
      expect(body['name']).to eq('Mine')
      expect(body['account_id']).to eq(account.id)
    end
  end

  describe 'PUT /brand_profile' do
    it 'creates the profile on first save' do
      put path, params: valid_params, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      profile = account.reload.glint_reach_brand_profile
      expect(profile.name).to eq('Acme Outdoors')
      expect(profile.preferred_languages).to eq(%w[en hi])
      expect(profile.approved_ctas).to eq(['Shop now', 'Learn more'])
      expect(response.parsed_body['brand_profile']['website_url']).to eq('https://acme.example')
    end

    it 'updates the existing profile instead of creating another' do
      profile = create(:glint_reach_brand_profile, account: account)

      put path, params: { brand_profile: { name: 'Renamed', approved_ctas: [] } }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(GlintReach::BrandProfile.where(account: account).count).to eq(1)
      expect(profile.reload.name).to eq('Renamed')
      expect(profile.approved_ctas).to eq([])
    end

    it 'never touches the profile of another account' do
      theirs = create(:glint_reach_brand_profile, account: other_account, name: 'Theirs')

      put path, params: valid_params, headers: admin.create_new_auth_token, as: :json

      expect(theirs.reload.name).to eq('Theirs')
      expect(account.reload.glint_reach_brand_profile).to be_present
    end

    it 'ignores account_id in the payload' do
      put path, params: { brand_profile: valid_params[:brand_profile].merge(account_id: other_account.id) },
                headers: admin.create_new_auth_token, as: :json

      expect(GlintReach::BrandProfile.last.account_id).to eq(account.id)
    end

    it 'returns 422 with field errors for invalid input' do
      put path, params: { brand_profile: { name: '', website_url: 'javascript:alert(1)', preferred_languages: ['english'] } },
                headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['attributes']).to include('name', 'website_url', 'preferred_languages')
      expect(GlintReach::BrandProfile.count).to eq(0)
    end
  end
end
