require 'rails_helper'

RSpec.describe GlintReach::VariantAsset do
  let(:campaign) { create(:glint_reach_campaign) }
  let(:variant) { create(:glint_reach_content_variant, content_item: create(:glint_reach_content_item, campaign: campaign)) }

  def asset_for(target_campaign)
    target_campaign.assets.create!(uploaded_by: target_campaign.created_by, upload: glint_reach_image_upload)
  end

  it 'links assets from the same campaign once' do
    asset = asset_for(campaign)
    described_class.create!(content_variant: variant, asset: asset)
    expect(described_class.new(content_variant: variant, asset: asset)).not_to be_valid
  end

  it 'rejects assets from another campaign' do
    link = described_class.new(content_variant: variant, asset: asset_for(create(:glint_reach_campaign)))
    expect(link).not_to be_valid
    expect(link.errors[:asset]).to be_present
  end
end
