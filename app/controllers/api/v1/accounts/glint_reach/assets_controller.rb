class Api::V1::Accounts::GlintReach::AssetsController < Api::V1::Accounts::GlintReach::BaseController
  RESULTS_PER_PAGE = 50

  before_action :fetch_campaign
  before_action :ensure_campaign_editable, except: [:index, :show]
  before_action :fetch_asset, except: [:index, :create]

  def index
    @current_page = [params[:page].to_i, 1].max
    @assets_count = @campaign.assets.count
    @assets = @campaign.assets.with_attached_file.recent.page(@current_page).per(RESULTS_PER_PAGE)
  end

  def show; end

  def create
    @asset = @campaign.assets.new(uploaded_by: Current.user, alt_text: params[:alt_text], upload: params[:file])
    @asset.save!
    render :show
  end

  # Updates alt text and/or replaces the file. Variant links are kept; the old blob is purged by
  # Active Storage once the replacement is saved.
  def update
    @asset.alt_text = params[:alt_text] if params.key?(:alt_text)
    @asset.upload = params[:file] if params[:file].present?
    @asset.save!
    render :show
  end

  def destroy
    @asset.destroy!
    head :ok
  end

  private

  def fetch_campaign
    @campaign = campaigns.find(params[:campaign_id])
  end

  def fetch_asset
    @asset = @campaign.assets.find(params[:id])
  end
end
