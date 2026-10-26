require 'rails_helper'

RSpec.describe GlintReachPolicy, type: :policy do
  subject(:glint_reach_policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }

  let(:administrator_context) do
    { user: administrator, account: account, account_user: account.account_users.find_by(user: administrator) }
  end
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.find_by(user: agent) } }

  permissions :show? do
    it { expect(glint_reach_policy).to permit(administrator_context, :glint_reach) }
    it { expect(glint_reach_policy).not_to permit(agent_context, :glint_reach) }
  end
end
