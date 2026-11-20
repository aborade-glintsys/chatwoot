require 'rails_helper'

RSpec.describe GlintReach::VerifySocialAccountsJob do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  before { allow(Chatwoot).to receive(:encryption_configured?).and_return(true) }

  def create_social(id:, expires_at: 30.days.from_now)
    GlintReach::SocialAccount.create!(
      account: account, connected_by: admin, provider: 'linkedin',
      provider_account_id: id, display_name: "User #{id}",
      access_token: "tok-#{id}", token_expires_at: expires_at,
      granted_scopes: %w[openid profile w_member_social]
    )
  end

  it 'marks expired accounts, revokes 401s, keeps valid ones and prunes old OAuth states' do
    expired = create_social(id: 'exp', expires_at: 1.hour.ago)
    revoked = create_social(id: 'rev')
    valid = create_social(id: 'ok')
    GlintReach::OauthState.issue!(account: account, user: admin, provider: 'linkedin')
    GlintReach::OauthState.update_all(expires_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations

    stub_request(:get, 'https://api.linkedin.com/v2/userinfo')
      .with(headers: { 'Authorization' => 'Bearer tok-rev' }).to_return(status: 401, body: '{}')
    stub_request(:get, 'https://api.linkedin.com/v2/userinfo')
      .with(headers: { 'Authorization' => 'Bearer tok-ok' }).to_return(status: 200, body: { sub: 'ok', name: 'Ok' }.to_json)

    described_class.perform_now

    expect(expired.reload).to have_attributes(status: 'expired', last_error_code: 'expired')
    expect(revoked.reload).to have_attributes(status: 'revoked', access_token: nil, last_error_code: 'revoked')
    expect(valid.reload).to be_connected
    expect(GlintReach::OauthState.count).to eq(0)
  end
end
