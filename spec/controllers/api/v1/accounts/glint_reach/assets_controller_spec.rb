require 'rails_helper'

RSpec.describe 'GlintReach Assets API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:campaign) { create(:glint_reach_campaign, account: account, created_by: admin) }
  let(:assets_path) { "/api/v1/accounts/#{account.id}/glint_reach/campaigns/#{campaign.id}/assets" }
  let(:headers) { admin.create_new_auth_token }

  before { account.enable_features!(:glint_reach) }

  def create_asset(target_campaign = campaign)
    target_campaign.assets.create!(uploaded_by: target_campaign.created_by, upload: glint_reach_image_upload)
  end

  describe 'POST create' do
    it 'uploads an image and returns metadata with expiring URLs' do
      post assets_path, params: { file: glint_reach_image_upload(width: 1080, height: 1080), alt_text: 'Hero' }, headers: headers

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body).to include('width' => 1080, 'height' => 1080, 'content_type' => 'image/png', 'alt_text' => 'Hero',
                              'url_expires_in' => 300)
      expect(body['url']).to start_with('/rails/active_storage/blobs/')
      expect(campaign.assets.count).to eq(1)
    end

    it 'returns 422 for a spoofed file' do
      upload = glint_reach_bytes_upload('<svg onload=alert(1)>', filename: 'x.png', content_type: 'image/png')
      post assets_path, params: { file: upload }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to include('not a JPEG')
      expect(GlintReach::Asset.count).to eq(0)
    end

    it 'returns 422 without a file' do
      post assets_path, params: { alt_text: 'x' }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for a locked campaign' do
      campaign.update_columns(status: GlintReach::Campaign.statuses[:archived]) # rubocop:disable Rails/SkipsModelValidations
      post assets_path, params: { file: glint_reach_image_upload }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 401 for agents and 403 when the flag is off' do
      post assets_path, params: { file: glint_reach_image_upload }, headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)

      account.disable_features!(:glint_reach)
      post assets_path, params: { file: glint_reach_image_upload }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'reading' do
    it 'lists and shows campaign assets' do
      asset = create_asset
      get assets_path, headers: headers
      expect(response.parsed_body['payload'].pluck('id')).to eq([asset.id])
      expect(response.parsed_body['meta']['count']).to eq(1)

      get "#{assets_path}/#{asset.id}", headers: headers
      expect(response.parsed_body['id']).to eq(asset.id)
    end

    it 'allows reading assets of a locked campaign' do
      create_asset
      campaign.update_columns(status: GlintReach::Campaign.statuses[:archived]) # rubocop:disable Rails/SkipsModelValidations
      get assets_path, headers: headers
      expect(response).to have_http_status(:success)
    end

    it "returns 404 for another account's asset, even through this account's campaign" do
      other_campaign = create(:glint_reach_campaign)
      other_asset = create_asset(other_campaign)

      get "#{assets_path}/#{other_asset.id}", headers: headers
      expect(response).to have_http_status(:not_found)

      get "/api/v1/accounts/#{account.id}/glint_reach/campaigns/#{other_campaign.id}/assets", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "denies users who are not members of the asset's account" do
      outsider = create(:user, account: create(:account), role: :administrator)
      asset = create_asset
      get "#{assets_path}/#{asset.id}", headers: outsider.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH update' do
    it 'updates alt text without touching the file' do
      asset = create_asset
      blob_id = asset.file.blob.id
      patch "#{assets_path}/#{asset.id}", params: { alt_text: 'New alt' }, headers: headers

      expect(asset.reload.alt_text).to eq('New alt')
      expect(asset.file.blob.id).to eq(blob_id)
    end

    it 'replaces the file' do
      asset = create_asset
      patch "#{assets_path}/#{asset.id}", params: { file: glint_reach_image_upload(width: 500, height: 900, format: 'jpeg') }, headers: headers

      expect(response).to have_http_status(:success)
      expect(asset.reload).to have_attributes(width: 500, height: 900, content_type: 'image/jpeg')
    end

    it 'keeps the original file when the replacement is invalid' do
      asset = create_asset
      blob_id = asset.file.blob.id
      patch "#{assets_path}/#{asset.id}", params: { file: glint_reach_image_upload(width: 50, height: 50) }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(asset.reload.file.blob.id).to eq(blob_id)
      expect(asset.width).to eq(400)
    end
  end

  describe 'DELETE destroy' do
    it 'removes the asset and purges its blob' do
      asset = create_asset
      perform_enqueued_jobs { delete "#{assets_path}/#{asset.id}", headers: headers }

      expect(response).to have_http_status(:success)
      expect(GlintReach::Asset.exists?(asset.id)).to be(false)
      expect(ActiveStorage::Blob.count).to eq(0)
    end
  end

  describe 'PUT variant assets' do
    let(:item) { create(:glint_reach_content_item, campaign: campaign) }
    let(:variant) { create(:glint_reach_content_variant, content_item: item) }
    let(:variant_assets_path) do
      "/api/v1/accounts/#{account.id}/glint_reach/campaigns/#{campaign.id}/content_items/#{item.id}/variants/#{variant.id}/assets"
    end

    it 'sets the ordered assets and returns them on the variant' do
      first = create_asset
      second = create_asset
      put variant_assets_path, params: { asset_ids: [second.id, first.id] }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['asset_ids']).to eq([second.id, first.id])
      expect(response.parsed_body['assets'].first['thumbnail_url']).to be_present
      expect(variant.reload.assets).to eq([second, first])
    end

    it 'clears assets with an empty list' do
      GlintReach::VariantAsset.create!(content_variant: variant, asset: create_asset)
      put variant_assets_path, params: { asset_ids: [] }, headers: headers, as: :json
      expect(variant.reload.assets).to be_empty
    end

    it 'rejects assets from another account without changing links' do
      own = create_asset
      GlintReach::VariantAsset.create!(content_variant: variant, asset: own)
      foreign = create_asset(create(:glint_reach_campaign))

      put variant_assets_path, params: { asset_ids: [own.id, foreign.id] }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(variant.reload.assets).to eq([own])
    end

    it 'rejects more than 10 assets' do
      put variant_assets_path, params: { asset_ids: (1..11).to_a }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('at most 10')
    end
  end
end
