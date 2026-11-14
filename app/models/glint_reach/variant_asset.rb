# Orders assets on a content variant. Both sides must belong to the same campaign, which also
# guarantees the same account.
# == Schema Information
#
# Table name: glint_reach_variant_assets
#
#  id                 :bigint           not null, primary key
#  position           :integer          default(0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  asset_id           :bigint           not null
#  content_variant_id :bigint           not null
#
# Indexes
#
#  idx_on_content_variant_id_asset_id_aceb8f0109  (content_variant_id,asset_id) UNIQUE
#  index_glint_reach_variant_assets_on_asset_id   (asset_id)
#
# Foreign Keys
#
#  fk_rails_...  (asset_id => glint_reach_assets.id) ON DELETE => cascade
#  fk_rails_...  (content_variant_id => glint_reach_content_variants.id) ON DELETE => cascade
#
class GlintReach::VariantAsset < ApplicationRecord
  MAX_PER_VARIANT = 10

  belongs_to :content_variant, class_name: 'GlintReach::ContentVariant'
  belongs_to :asset, class_name: 'GlintReach::Asset'

  validates :asset_id, uniqueness: { scope: :content_variant_id }
  validate :same_campaign

  private

  def same_campaign
    return if content_variant.nil? || asset.nil?
    return if content_variant.content_item.campaign_id == asset.campaign_id

    errors.add(:asset, :invalid)
  end
end
