require 'rails_helper'

RSpec.describe 'GlintReach Social Accounts API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:headers) { admin.create_new_auth_token }
  let(:base) { "/api/v1/accounts/#{account.id}/glint_reach" }

  before do
    account.enable_features!(:glint_reach)
    allow(Chatwoot).to receive(:encryption_configured?).and_return(true)
    InstallationConfig.where(name: 'GLINT_REACH_LINKEDIN_CLIENT_ID').first_or_create!(value: 'li-id')
    InstallationConfig.where(name: 'GLINT_REACH_LINKEDIN_CLIENT_SECRET').first_or_create!(value: 'li-secret')
  end

  around do |example|
    with_modified_env FRONTEND_URL: 'https://app.example.com' do
      example.run
    end
  end

  describe 'GET /social_providers' do
    it 'lists LinkedIn capabilities and configuration state' do
      get "#{base}/social_providers", headers: headers

      expect(response).to have_http_status(:success)
      linkedin = response.parsed_body['payload'].first
      expect(linkedin).to include('key' => 'linkedin', 'configured' => true, 'connectable' => true)
      expect(linkedin['capabilities']).to include('post_types' => %w[text image], 'max_text_length' => 3_000, 'max_images' => 1)
    end
  end

  describe 'OAuth start and callback' do
    it 'starts OAuth with a browser-bound cookie and completes on callback without exposing tokens' do
      id_token = JWT.encode({ 'iss' => 'https://www.linkedin.com/oauth', 'aud' => 'li-id', 'exp' => 1.hour.from_now.to_i }, nil, 'none')
      stub_request(:post, 'https://www.linkedin.com/oauth/v2/accessToken')
        .to_return(status: 200, body: { access_token: 'secret-tok', expires_in: 3600,
                                        scope: 'openid profile w_member_social', id_token: id_token }.to_json)
      stub_request(:get, 'https://api.linkedin.com/v2/userinfo')
        .to_return(status: 200, body: { sub: 'mem-1', name: 'Ada' }.to_json)

      post "#{base}/social_accounts/authorize", params: { provider: 'linkedin' }, headers: headers, as: :json
      expect(response).to have_http_status(:success)
      state = URI.decode_www_form(URI.parse(response.parsed_body['url']).query).to_h.fetch('state')
      expect(Array(response.headers['Set-Cookie']).join).to include(GlintReach::Social::OauthFlow::COOKIE_NAME)

      get '/glint_reach/oauth/linkedin/callback', params: { state: state, code: 'abc' }
      expect(response).to redirect_to("https://app.example.com/app/accounts/#{account.id}/glint-reach/social-accounts?oauth=connected")

      get "#{base}/social_accounts", headers: headers
      item = response.parsed_body['payload'].sole
      expect(item).to include('display_name' => 'Ada', 'status' => 'connected')
      expect(item.keys).not_to include('access_token', 'refresh_token')
      expect(response.body).not_to include('secret-tok')
    end

    it 'rejects a callback without the browser cookie' do
      post "#{base}/social_accounts/authorize", params: { provider: 'linkedin' }, headers: headers, as: :json
      state = URI.decode_www_form(URI.parse(response.parsed_body['url']).query).to_h.fetch('state')
      cookies.delete(GlintReach::Social::OauthFlow::COOKIE_NAME)

      get '/glint_reach/oauth/linkedin/callback', params: { state: state, code: 'abc' }
      expect(response).to redirect_to('https://app.example.com/')
      expect(GlintReach::SocialAccount.count).to eq(0)
    end

    it 'returns 422 when encryption keys are not configured' do
      allow(Chatwoot).to receive(:encryption_configured?).and_return(false)
      post "#{base}/social_accounts/authorize", params: { provider: 'linkedin' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('encryption_required')
    end
  end

  describe 'DELETE /social_accounts/:id and isolation' do
    let!(:social) do
      GlintReach::SocialAccount.create!(
        account: account, connected_by: admin, provider: 'linkedin',
        provider_account_id: 'mem-1', display_name: 'Ada', access_token: 'tok-1',
        granted_scopes: %w[openid profile w_member_social]
      )
    end

    it 'disconnects and wipes tokens' do
      stub_request(:post, 'https://www.linkedin.com/oauth/v2/revoke').to_return(status: 200)
      delete "#{base}/social_accounts/#{social.id}", headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['status']).to eq('revoked')
      expect(social.reload.access_token).to be_nil
    end

    it "returns 404 when attempting to disconnect another account's social account" do
      other_account = create(:account)
      other_admin = create(:user, account: other_account, role: :administrator)
      other_social = GlintReach::SocialAccount.create!(
        account: other_account, connected_by: other_admin, provider: 'linkedin',
        provider_account_id: 'mem-2', display_name: 'Bob', access_token: 'tok-2'
      )

      delete "#{base}/social_accounts/#{other_social.id}", headers: headers
      expect(response).to have_http_status(:not_found)
      expect(other_social.reload).to be_connected
    end

    it 'enforces admin role and glint_reach feature flag' do
      get "#{base}/social_accounts", headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)

      account.disable_features!(:glint_reach)
      get "#{base}/social_accounts", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
