class Api::V1::Accounts::GlintReach::GenerationsController < Api::V1::Accounts::GlintReach::BaseController
  RECENT_LIMIT = 20

  before_action :fetch_campaign, only: [:index, :create]

  def index
    @generations = @campaign.generations.recent.limit(RECENT_LIMIT)
  end

  def show
    @generation = GlintReach::Generation.where(account_id: Current.account.id).find(params[:id])
  end

  def create
    @generation = GlintReach::Generators::Enqueuer.new(campaign: @campaign, user: Current.user, params: generation_params).perform
    render :show, status: :accepted
  rescue GlintReach::Generators::Enqueuer::Rejected => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_campaign
    @campaign = campaigns.find(params[:campaign_id])
  end

  def generation_params
    params.require(:generation).permit(:kind, :content_item_id, :content_variant_id, :count, :instruction, platforms: [])
  end
end
