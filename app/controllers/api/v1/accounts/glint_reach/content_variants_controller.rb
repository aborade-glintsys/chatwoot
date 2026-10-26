class Api::V1::Accounts::GlintReach::ContentVariantsController < Api::V1::Accounts::GlintReach::BaseController
  before_action :fetch_parents
  before_action :ensure_campaign_editable
  before_action :fetch_variant, except: [:create]

  def create
    @variant = @content_item.variants.create!(variant_params)
    render :show
  end

  def update
    @variant.update!(variant_params)
    render :show
  end

  def destroy
    @variant.destroy!
    head :ok
  end

  def transition
    @variant.transition_to!(params.require(:status))
    render :show
  end

  private

  def fetch_parents
    @campaign = campaigns.find(params[:campaign_id])
    @content_item = @campaign.content_items.find(params[:content_item_id])
  end

  def fetch_variant
    @variant = @content_item.variants.find(params[:id])
  end

  def variant_params
    params.require(:variant).permit(:platform, :body, :call_to_action, hashtags: [])
  end
end
