require 'rails_helper'

RSpec.describe GlintReach::Social::OauthFlow do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

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

  def stub_linkedin(scopes: 'openid profile email w_member_social', sub: 'member-1', name: 'Ada')
    id_token = JWT.encode({ 'iss' => 'https://www.linkedin.com/oauth', 'aud' => 'li-id', 'exp' => 1.hour.from_now.to_i }, nil, 'none')
    stub_request(:post, 'https://www.linkedin.com/oauth/v2/accessToken')
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 5_184_000, scope: scopes, id_token: id_token }.to_json)
    stub_request(:get, 'https://api.linkedin.com/v2/userinfo')
      .to_return(status: 200, body: { sub: sub, name: name }.to_json)
  end

  def start_flow
    result = described_class.start(account: account, user: admin, provider_key: 'linkedin')
    state = URI.decode_www_form(URI.parse(result[:url]).query).to_h.fetch('state')
    [state, result[:nonce], result[:url]]
  end

  it 'derives redirect URI strictly from FRONTEND_URL' do
    expect(described_class.redirect_uri_for('linkedin')).to eq('https://app.example.com/glint_reach/oauth/linkedin/callback')
    with_modified_env FRONTEND_URL: 'javascript:alert(1)' do
      expect { described_class.redirect_uri_for('linkedin') }.to raise_error(GlintReach::Social::Error::NotConfigured)
    end
  end

  it 'refuses to start without encryption keys' do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(false)
    expect { described_class.start(account: account, user: admin, provider_key: 'linkedin') }
      .to raise_error(GlintReach::Social::Error::EncryptionRequired)
  end

  it 'completes OAuth, stores the account and prevents state replay' do
    stub_linkedin
    state, nonce, = start_flow

    completion = described_class.complete(provider_key: 'linkedin', state: state, code: 'ok', error: nil, raw_nonce: nonce)
    expect(completion).to have_attributes(account_id: account.id, outcome: 'connected', error_code: nil)
    expect(completion.social_account).to have_attributes(provider: 'linkedin', provider_account_id: 'member-1',
                                                         display_name: 'Ada', status: 'connected')

    replay = described_class.complete(provider_key: 'linkedin', state: state, code: 'ok', error: nil, raw_nonce: nonce)
    expect(replay).to have_attributes(account_id: nil, outcome: 'error', error_code: 'invalid_state')
  end

  it 'rejects missing, expired, wrong-provider and wrong-cookie states' do
    state, nonce, = start_flow

    wrong_cookie = described_class.complete(provider_key: 'linkedin', state: state, code: 'ok', error: nil, raw_nonce: 'other')
    expect(wrong_cookie.error_code).to eq('invalid_state')

    wrong_provider = described_class.complete(provider_key: 'other', state: state, code: 'ok', error: nil, raw_nonce: nonce)
    expect(wrong_provider.error_code).to eq('invalid_state')

    travel 11.minutes do
      expired = described_class.complete(provider_key: 'linkedin', state: state, code: 'ok', error: nil, raw_nonce: nonce)
      expect(expired.error_code).to eq('invalid_state')
    end
    expect(GlintReach::SocialAccount.count).to eq(0)
  end

  it 'maps user cancellation on the provider to access_denied' do
    state, nonce, = start_flow
    completion = described_class.complete(provider_key: 'linkedin', state: state, code: nil,
                                          error: 'user_cancelled_authorize', raw_nonce: nonce)
    expect(completion).to have_attributes(account_id: account.id, outcome: 'error', error_code: 'access_denied')
  end

  it 'records missing_scopes instead of connected when w_member_social is omitted' do
    stub_linkedin(scopes: 'openid profile')
    state, nonce, = start_flow
    completion = described_class.complete(provider_key: 'linkedin', state: state, code: 'ok', error: nil, raw_nonce: nonce)

    expect(completion).to have_attributes(outcome: 'missing_scopes', error_code: 'missing_scopes')
    expect(completion.social_account).to be_missing_scopes
    expect(completion.social_account.last_error_message).to include('w_member_social')
  end

  it 're-checks admin role and feature flag on callback' do
    state, nonce, = start_flow
    account.disable_features!(:glint_reach)
    completion = described_class.complete(provider_key: 'linkedin', state: state, code: 'ok', error: nil, raw_nonce: nonce)
    expect(completion.error_code).to eq('invalid_state')
  end

  it 'disconnects and wipes tokens even if provider revoke fails' do
    stub_linkedin
    state, nonce, = start_flow
    social = described_class.complete(provider_key: 'linkedin', state: state, code: 'ok', error: nil, raw_nonce: nonce).social_account

    stub_request(:post, 'https://www.linkedin.com/oauth/v2/revoke').to_timeout
    described_class.disconnect(social_account: social)

    expect(social.reload).to have_attributes(status: 'revoked', access_token: nil, refresh_token: nil, last_error_code: 'disconnected')
  end
end
