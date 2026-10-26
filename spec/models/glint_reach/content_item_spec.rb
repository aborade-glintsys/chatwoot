require 'rails_helper'

RSpec.describe GlintReach::ContentItem do
  let(:campaign) { create(:glint_reach_campaign) }

  it 'derives account_id from its campaign, ignoring any other value' do
    item = create(:glint_reach_content_item, campaign: campaign, account_id: create(:account).id)

    expect(item.account_id).to eq(campaign.account_id)
  end

  it 'requires a title and a known content type' do
    item = described_class.new(campaign: campaign, content_type: 'hologram')

    expect(item).not_to be_valid
    expect(item.errors.attribute_names).to include(:title, :content_type)
  end

  it 'transitions draft -> ready -> archived and rejects archived -> draft' do
    item = create(:glint_reach_content_item, campaign: campaign)

    item.transition_to!(:ready)
    item.transition_to!(:archived)

    expect { item.transition_to!(:draft) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
