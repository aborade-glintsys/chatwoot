class Api::V1::Accounts::GlintReach::CampaignsController < Api::V1::Accounts::GlintReach::BaseController
  RESULTS_PER_PAGE = 25

  before_action :validate_status_filter, only: [:index]
  before_action :fetch_campaign, except: [:index, :create]
  before_action :ensure_campaign_editable, only: [:update]

  def index
    @current_page = [params[:page].to_i, 1].max
    filtered = filtered_campaigns
    @campaigns_count = filtered.count
    @campaigns = filtered.includes(:created_by).order(updated_at: :desc).page(@current_page).per(RESULTS_PER_PAGE)
  end

  def show; end

  def create
    @campaign = campaigns.create!(campaign_params.merge(created_by: Current.user))
    render :show
  end

  def update
    @campaign.update!(campaign_params)
    render :show
  end

  # Safe deletion: campaigns are archived, never hard deleted.
  def destroy
    @campaign.transition_to!(:archived) unless @campaign.archived?
    render :show
  end

  def transition
    @campaign.transition_to!(params.require(:status))
    render :show
  end

  private

  def fetch_campaign
    @campaign = campaigns.includes(:created_by, content_items: :variants).find(params[:id])
  end

  def filtered_campaigns
    scope = params[:status].present? ? campaigns.where(status: params[:status]) : campaigns.not_archived
    scope = scope.search_by_name(params[:search].delete("\0")) if params[:search].present?
    scope
  end

  def validate_status_filter
    return if params[:status].blank? || GlintReach::Campaign.statuses.key?(params[:status])

    render json: { error: I18n.t('errors.glint_reach.invalid_status_filter') }, status: :unprocessable_entity
  end

  def campaign_params
    params.require(:campaign).permit(:name, :objective, :brief, :target_audience, :starts_at, :ends_at)
  end
end
