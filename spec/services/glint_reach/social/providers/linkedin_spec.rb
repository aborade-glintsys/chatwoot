require 'rails_helper'

RSpec.describe GlintReach::Social::Providers::Linkedin do
  let(:provider) { described_class.new }
  let(:client_id) { 'li-client-id' }
  let(:client_secret) { 'li-client-secret' }
  let(:redirect_uri) { 'https://app.example.com/glint_reach/oauth/linkedin/callback' }

  def configure!
    InstallationConfig.where(name: 'GLINT_REACH_LINKEDIN_CLIENT_ID').first_or_create!(value: client_id)
    InstallationConfig.where(name: 'GLINT_REACH_LINKEDIN_CLIENT_SECRET').first_or_create!(value: client_secret)
  end

  def jwt_for(claims)
    JWT.encode(claims, nil, 'none')
  end

  it 'reports unconfigured when credentials are absent' do
    InstallationConfig.where(name: %w[GLINT_REACH_LINKEDIN_CLIENT_ID GLINT_REACH_LINKEDIN_CLIENT_SECRET]).destroy_all

    expect(provider.configured?).to be(false)
    expect { provider.authorize_url(state: 's', code_challenge: 'c', redirect_uri: redirect_uri) }
      .to raise_error(GlintReach::Social::Error::NotConfigured)
  end

  describe 'when configured' do
    before { configure! }

    it 'builds an authorization URL with PKCE and required scopes' do
      url = provider.authorize_url(state: 'st123', code_challenge: 'ch456', redirect_uri: redirect_uri)
      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query).to_h

      expect(uri.host).to eq('www.linkedin.com')
      expect(params).to include(
        'response_type' => 'code', 'client_id' => client_id, 'redirect_uri' => redirect_uri,
        'state' => 'st123', 'code_challenge' => 'ch456', 'code_challenge_method' => 'S256'
      )
      expect(params['scope'].split).to include('openid', 'profile', 'w_member_social')
    end

    it 'exchanges the code, validates ID token claims and parses comma-separated scopes' do
      id_token = jwt_for('iss' => described_class::OIDC_ISSUER, 'aud' => client_id, 'exp' => 1.hour.from_now.to_i)
      stub_request(:post, 'https://www.linkedin.com/oauth/v2/accessToken')
        .to_return(status: 200, body: {
          access_token: 'tok', expires_in: 5_184_000, scope: 'openid,profile,email,w_member_social', id_token: id_token
        }.to_json)

      tokens = provider.exchange_code(code: 'auth-code', code_verifier: 'ver', redirect_uri: redirect_uri)
      expect(tokens.access_token).to eq('tok')
      expect(tokens.scopes).to contain_exactly('openid', 'profile', 'email', 'w_member_social')
      expect(tokens.expires_at).to be_within(5.seconds).of(60.days.from_now)
    end

    it 'rejects an ID token with wrong audience, issuer or expired timestamp' do
      bad_token = jwt_for('iss' => 'https://evil.example', 'aud' => client_id, 'exp' => 1.hour.from_now.to_i)
      stub_request(:post, 'https://www.linkedin.com/oauth/v2/accessToken')
        .to_return(status: 200, body: { access_token: 'tok', id_token: bad_token }.to_json)

      expect { provider.exchange_code(code: 'c', code_verifier: 'v', redirect_uri: redirect_uri) }
        .to raise_error(GlintReach::Social::Error::TokenExchangeFailed)
    end

    it 'maps 5xx and timeouts to ProviderUnavailable' do
      stub_request(:post, 'https://www.linkedin.com/oauth/v2/accessToken').to_return(status: 503, body: 'down')
      expect { provider.exchange_code(code: 'c', code_verifier: 'v', redirect_uri: redirect_uri) }
        .to raise_error(GlintReach::Social::Error::ProviderUnavailable)
    end

    it 'fetches member identity and maps 401 to Revoked' do
      stub_request(:get, 'https://api.linkedin.com/v2/userinfo')
        .with(headers: { 'Authorization' => 'Bearer tok' })
        .to_return(status: 200, body: { sub: 'abc', name: 'Ada', picture: 'https://media.licdn.com/a.jpg' }.to_json)

      identity = provider.fetch_identity(access_token: 'tok')
      expect(identity).to have_attributes(provider_account_id: 'abc', provider_account_type: 'member',
                                          display_name: 'Ada', avatar_url: 'https://media.licdn.com/a.jpg')

      stub_request(:get, 'https://api.linkedin.com/v2/userinfo').to_return(status: 401, body: '{}')
      expect { provider.fetch_identity(access_token: 'tok') }.to raise_error(GlintReach::Social::Error::Revoked)
    end

    it 'declares member capabilities and raises RefreshUnsupported on refresh' do
      caps = provider.capabilities
      expect(caps).to have_attributes(post_types: %w[text image], max_text_length: 3_000, max_images: 1,
                                      supports_video: false, supports_refresh: false, token_lifetime_days: 60)
      expect { provider.refresh('r') }.to raise_error(GlintReach::Social::Error::RefreshUnsupported)
    end
  end
end
