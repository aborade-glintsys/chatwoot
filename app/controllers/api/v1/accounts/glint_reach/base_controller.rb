class Api::V1::Accounts::GlintReach::BaseController < Api::V1::Accounts::BaseController
  before_action -> { authorize :glint_reach, :show? }
  before_action :ensure_glint_reach_enabled

  private

  def ensure_glint_reach_enabled
    return if Current.account.feature_enabled?(:glint_reach)

    render json: { error: I18n.t('errors.glint_reach.not_enabled') }, status: :forbidden
  end

  def campaigns
    Current.account.glint_reach_campaigns
  end

  def ensure_campaign_editable
    return unless @campaign.locked?

    render json: { error: I18n.t('errors.glint_reach.campaign_locked', status: @campaign.status) }, status: :unprocessable_entity
  end
end
