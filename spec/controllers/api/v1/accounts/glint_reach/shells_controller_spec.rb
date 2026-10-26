require 'rails_helper'

RSpec.describe 'GlintReach Shell API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:path) { "/api/v1/accounts/#{account.id}/glint_reach/shell" }

  describe 'GET /api/v1/accounts/{account.id}/glint_reach/shell' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get path

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when GlintReach is enabled' do
      before { account.enable_features!(:glint_reach) }

      it 'returns unauthorized for an agent' do
        get path, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for an administrator of another account' do
        other_admin = create(:user, account: create(:account), role: :administrator)

        get path, headers: other_admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns the shell with every module unavailable for an administrator' do
        get path, headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['product_name']).to eq('GlintReach')
        expect(body['tagline']).to eq('Create once. Reach everywhere.')
        expect(body['modules'].pluck('key')).to eq(%w[overview campaigns content_studio calendar social_accounts analytics])
        expect(body['modules'].pluck('available')).to all(be(false))
      end
    end

    context 'when GlintReach is disabled' do
      it 'returns forbidden for an administrator' do
        get path, headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq('GlintReach is not enabled for this account')
      end

      it 'is disabled by default for new accounts' do
        expect(account.feature_enabled?(:glint_reach)).to be(false)
      end
    end
  end
end
