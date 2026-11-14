require 'rails_helper'

RSpec.describe GlintReach::Asset do
  let(:campaign) { create(:glint_reach_campaign) }

  def build_asset(upload: glint_reach_image_upload, **attrs)
    campaign.assets.new(uploaded_by: campaign.created_by, upload: upload, **attrs)
  end

  it 'stores the validated file and cached metadata' do
    asset = build_asset(alt_text: '  Blue square  ')
    asset.save!

    expect(asset.reload).to have_attributes(account_id: campaign.account_id, content_type: 'image/png', width: 400,
                                            height: 300, alt_text: 'Blue square', filename: 'creative.png')
    expect(asset.file).to be_attached
    expect(asset.file.blob.content_type).to eq('image/png')
    expect(asset.checksum).to eq(asset.file.blob.checksum)
  end

  it 'requires a file' do
    asset = build_asset(upload: nil)
    expect(asset).not_to be_valid
    expect(asset.errors[:file]).to be_present
  end

  it 'adds the inspector error to file and does not attach invalid uploads' do
    asset = build_asset(upload: glint_reach_bytes_upload('nope', filename: 'x.png', content_type: 'image/png'))

    expect(asset.save).to be(false)
    expect(asset.errors[:file].join).to include('not a JPEG')
    expect(ActiveStorage::Blob.count).to eq(0)
  end

  it 'limits alt text length' do
    expect(build_asset(alt_text: 'a' * 1001)).not_to be_valid
  end

  it 'replaces the file, purges the old blob and keeps variant links' do
    asset = build_asset
    asset.save!
    variant = create(:glint_reach_content_variant, content_item: create(:glint_reach_content_item, campaign: campaign))
    GlintReach::VariantAsset.create!(content_variant: variant, asset: asset)
    old_blob = asset.file.blob

    asset.upload = glint_reach_image_upload(width: 800, height: 800, format: 'jpeg')
    perform_enqueued_jobs { asset.save! }

    expect(asset.reload).to have_attributes(content_type: 'image/jpeg', width: 800)
    expect(ActiveStorage::Blob.exists?(old_blob.id)).to be(false)
    expect(variant.reload.assets).to eq([asset])
  end

  it 'purges the blob and removes links when destroyed' do
    asset = build_asset
    asset.save!
    variant = create(:glint_reach_content_variant, content_item: create(:glint_reach_content_item, campaign: campaign))
    GlintReach::VariantAsset.create!(content_variant: variant, asset: asset)

    perform_enqueued_jobs { asset.destroy! }
    expect(ActiveStorage::Blob.count).to eq(0)
    expect(GlintReach::VariantAsset.count).to eq(0)
  end

  it 'issues expiring signed URLs only when a file is attached' do
    asset = build_asset
    asset.save!

    expect(asset.url).to start_with('/rails/active_storage/blobs/')
    expect(build_asset(upload: nil).url).to be_nil
  end

  it 'makes URLs stop resolving after expiry' do
    asset = build_asset
    asset.save!
    signed_id = asset.url.split('/')[-2]

    expect(ActiveStorage::Blob.find_signed(signed_id)).to eq(asset.file.blob)
    travel(6.minutes) { expect(ActiveStorage::Blob.find_signed(signed_id)).to be_nil }
  end
end
