# Lists registered social providers with configuration status, approval notes and capabilities.
class Api::V1::Accounts::GlintReach::SocialProvidersController < Api::V1::Accounts::GlintReach::BaseController
  def index
    render json: { payload: GlintReach::Social::Providers.all.map(&:metadata) }
  end
end
