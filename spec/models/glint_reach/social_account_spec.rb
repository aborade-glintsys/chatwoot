require 'rails_helper'

RSpec.describe GlintReach::SocialAccount do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  def build_social(**attrs)
    described_class.new(
      account: account, connected_by: admin, provider: 'linkedin',
      provider_account_id: 'member-1', display_name: 'Ada Lovelace',
      access_token: 'secret-access-token', granted_scopes: %w[openid profile w_member_social],
      **attrs
    )
  end

  it 'refuses to save tokens when Active Record Encryption is not configured' do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(false)
    record = build_social

    expect(record).not_to be_valid
    expect(record.errors[:base].join).to include('Encryption')
  end

  it 'saves and enforces uniqueness per account and provider identity' do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(true)
    first = build_social
    first.save!

    duplicate = build_social
    expect(duplicate).not_to be_valid

    # The same external member can be connected independently by a second Chatwoot account.
    other_account = create(:account)
    other_admin = create(:user, account: other_account, role: :administrator)
    separate = build_social(account: other_account, connected_by: other_admin, access_token: 'other-token')
    expect(separate).to be_valid
    separate.save!
    expect(separate.account_id).to eq(other_account.id)
  end

  it 'encrypts tokens at rest when encryption keys are configured' do
    skip 'encryption keys missing; run with ACTIVE_RECORD_ENCRYPTION_* env vars' unless Chatwoot.encryption_configured?

    record = build_social(access_token: 'raw-access-123', refresh_token: 'raw-refresh-456')
    record.save!
    record.reload

    expect(record.read_attribute_before_type_cast(:access_token).to_s).not_to include('raw-access-123')
    expect(record.read_attribute_before_type_cast(:refresh_token).to_s).not_to include('raw-refresh-456')
    expect(record.access_token).to eq('raw-access-123')
    expect(record.refresh_token).to eq('raw-refresh-456')
  end

  it 'never writes tokens to audit logs' do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(true)
    record = build_social(access_token: 'super-secret-token', refresh_token: 'super-secret-refresh')
    record.save!

    audits = Audited::Audit.where(auditable_type: described_class.name, auditable_id: record.id)
    expect(audits.map(&:audited_changes).to_s).not_to include('super-secret-token', 'super-secret-refresh')
  end

  it 'detects expired tokens and clears tokens on disconnect' do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(true)
    record = build_social(token_expires_at: 1.minute.ago)
    record.save!

    expect(record.token_expired?).to be(true)
    record.clear_tokens!
    expect(record.reload).to have_attributes(access_token: nil, refresh_token: nil, token_expires_at: nil)
  end
end
