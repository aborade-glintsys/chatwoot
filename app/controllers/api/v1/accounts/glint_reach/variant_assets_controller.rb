# Replaces the ordered list of assets on a content variant. Assets are looked up through the
# variant's campaign, so IDs from another campaign or account are rejected.
class Api::V1::Accounts::GlintReach::VariantAssetsController < Api::V1::Accounts::GlintReach::BaseController
  before_action :fetch_variant
  before_action :ensure_campaign_editable

  def update
    ids = asset_ids
    return reject(:too_many_on_variant, max: GlintReach::VariantAsset::MAX_PER_VARIANT) if ids.size > GlintReach::VariantAsset::MAX_PER_VARIANT

    assets = @campaign.assets.where(id: ids).index_by(&:id)
    return reject(:not_in_campaign) unless assets.size == ids.size

    replace_links(ids)
    render 'api/v1/accounts/glint_reach/content_variants/show'
  end

  private

  def fetch_variant
    @campaign = campaigns.find(params[:campaign_id])
    @content_item = @campaign.content_items.find(params[:content_item_id])
    @variant = @content_item.variants.find(params[:variant_id])
  end

  # An empty or missing list clears the variant's assets.
  def asset_ids
    Array(params.permit(asset_ids: [])[:asset_ids]).map(&:to_i).select(&:positive?).uniq
  end

  def replace_links(ids)
    ActiveRecord::Base.transaction do
      @variant.lock!
      raise GlintReach::Workflow::Conflict, I18n.t('errors.glint_reach.workflow.content_locked') unless @variant.editable?

      @variant.variant_assets.delete_all
      ids.each_with_index { |id, position| @variant.variant_assets.create!(asset_id: id, position: position) }
    end
    @variant.reload
  end

  def reject(key, **)
    render json: { error: I18n.t("errors.glint_reach.assets.#{key}", **) }, status: :unprocessable_entity
  end
end
