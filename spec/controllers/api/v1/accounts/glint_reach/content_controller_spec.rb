require 'rails_helper'

RSpec.describe 'GlintReach Content API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:campaign) { create(:glint_reach_campaign, account: account, created_by: admin) }
  let(:items_path) { "/api/v1/accounts/#{account.id}/glint_reach/campaigns/#{campaign.id}/content_items" }
  let(:content_item) { create(:glint_reach_content_item, campaign: campaign) }
  let(:variants_path) { "#{items_path}/#{content_item.id}/variants" }
  let(:headers) { admin.create_new_auth_token }

  before { account.enable_features!(:glint_reach) }

  describe 'content items' do
    it 'creates a content item' do
      post items_path, params: { content_item: { title: 'Teaser', content_type: 'video' } }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(campaign.content_items.last).to have_attributes(title: 'Teaser', content_type: 'video', account_id: account.id)
    end

    it 'returns 422 for invalid input' do
      post items_path, params: { content_item: { title: '', content_type: 'hologram' } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'updates, transitions and deletes a content item' do
      patch "#{items_path}/#{content_item.id}", params: { content_item: { title: 'New' } }, headers: headers, as: :json
      expect(content_item.reload.title).to eq('New')

      post "#{items_path}/#{content_item.id}/transition", params: { status: 'ready' }, headers: headers, as: :json
      expect(content_item.reload).to be_ready

      delete "#{items_path}/#{content_item.id}", headers: headers, as: :json
      expect(GlintReach::ContentItem.exists?(content_item.id)).to be(false)
    end

    it 'returns 422 for an invalid transition' do
      post "#{items_path}/#{content_item.id}/transition", params: { status: 'published' }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects changes when the campaign is archived' do
      campaign.update!(status: :archived)

      post items_path, params: { content_item: { title: 'Late', content_type: 'post' } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(campaign.content_items.count).to eq(0)
    end

    it 'returns 401 for an agent' do
      post items_path, params: { content_item: { title: 'X', content_type: 'post' } }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'cannot reach a content item through another campaign' do
      other_campaign_item = create(:glint_reach_content_item, campaign: create(:glint_reach_campaign, account: account, created_by: admin))

      patch "#{items_path}/#{other_campaign_item.id}", params: { content_item: { title: 'Hijack' } }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot add content to a campaign of another account' do
      foreign = create(:glint_reach_campaign)
      foreign.account.enable_features!(:glint_reach)

      post "/api/v1/accounts/#{account.id}/glint_reach/campaigns/#{foreign.id}/content_items",
           params: { content_item: { title: 'X', content_type: 'post' } }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
      expect(foreign.content_items.count).to eq(0)
    end
  end

  describe 'variants' do
    it 'creates a variant with normalized hashtags' do
      post variants_path, params: { variant: { platform: 'linkedin', body: 'Hello', call_to_action: 'Shop now', hashtags: ['#Spring'] } },
                          headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('platform' => 'linkedin', 'hashtags' => ['Spring'], 'status' => 'draft')
    end

    it 'returns 422 for a duplicate platform' do
      create(:glint_reach_content_variant, content_item: content_item, platform: :x)

      post variants_path, params: { variant: { platform: 'x', body: 'Again' } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'updates, transitions and deletes a variant' do
      variant = create(:glint_reach_content_variant, content_item: content_item)

      patch "#{variants_path}/#{variant.id}", params: { variant: { body: 'Edited' } }, headers: headers, as: :json
      expect(variant.reload.body).to eq('Edited')

      post "#{variants_path}/#{variant.id}/transition", params: { status: 'ready' }, headers: headers, as: :json
      expect(variant.reload).to be_ready

      delete "#{variants_path}/#{variant.id}", headers: headers, as: :json
      expect(GlintReach::ContentVariant.exists?(variant.id)).to be(false)
    end

    it 'returns 404 for a missing variant' do
      patch "#{variants_path}/0", params: { variant: { body: 'X' } }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
