require 'rails_helper'

RSpec.describe GlintReach::BrandProfile do
  let(:account) { create(:account) }

  it 'records create and update in the account audit log' do
    profile = create(:glint_reach_brand_profile, account: account)
    profile.update!(name: 'Renamed')

    audits = Enterprise::AuditLog.where(auditable: profile).order(:version)
    expect(audits.pluck(:action)).to eq(%w[create update])
    expect(audits.pluck(:associated_id).uniq).to eq([account.id])
  end
end
