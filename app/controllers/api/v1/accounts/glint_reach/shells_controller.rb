class Api::V1::Accounts::GlintReach::ShellsController < Api::V1::Accounts::BaseController
  MODULES = %w[overview campaigns content_studio calendar social_accounts analytics].freeze

  before_action -> { authorize :glint_reach, :show? }
  before_action :ensure_glint_reach_enabled

  def show
    @modules = MODULES
  end

  private

  def ensure_glint_reach_enabled
    return if Current.account.feature_enabled?(:glint_reach)

    render json: { error: I18n.t('errors.glint_reach.not_enabled') }, status: :forbidden
  end
end
