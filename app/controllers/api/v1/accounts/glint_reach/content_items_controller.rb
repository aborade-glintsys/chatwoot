class Api::V1::Accounts::GlintReach::ContentItemsController < Api::V1::Accounts::GlintReach::BaseController
  before_action :fetch_campaign
  before_action :ensure_campaign_editable
  before_action :fetch_content_item, except: [:create]

  def create
    @content_item = @campaign.content_items.create!(content_item_params)
    render :show
  end

  def update
    @content_item.update!(content_item_params)
    render :show
  end

  def destroy
    @content_item.destroy!
    head :ok
  end

  def transition
    @content_item.transition_to!(params.require(:status))
    render :show
  end

  private

  def fetch_campaign
    @campaign = campaigns.find(params[:campaign_id])
  end

  def fetch_content_item
    @content_item = @campaign.content_items.find(params[:id])
  end

  def content_item_params
    params.require(:content_item).permit(:title, :content_type)
  end
end
