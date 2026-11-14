require 'rails_helper'

RSpec.describe GlintReach::Campaign do
  let(:account) { create(:account) }
  let(:creator) { create(:user, account: account, role: :administrator) }

  it 'records create, update and status transitions in the account audit log' do
    campaign = create(:glint_reach_campaign, account: account, created_by: creator)
    campaign.update!(name: 'Renamed')
    campaign.transition_to!(:active)

    audits = Enterprise::AuditLog.where(auditable: campaign).order(:version)
    expect(audits.pluck(:action)).to eq(%w[create update update])
    expect(audits.pluck(:associated_id).uniq).to eq([account.id])
    expect(audits.last.audited_changes['status']).to eq([0, 1])
  end
end
