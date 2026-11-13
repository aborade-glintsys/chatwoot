require 'rails_helper'

RSpec.describe GlintReach::Generation do
  let(:campaign) { create(:glint_reach_campaign) }
  let(:item) { create(:glint_reach_content_item, campaign: campaign) }
  let(:variant) { create(:glint_reach_content_variant, content_item: item) }

  def build_generation(**attrs)
    described_class.new(campaign: campaign, requested_by: campaign.created_by, kind: :strategy, **attrs)
  end

  it 'derives account_id from the campaign' do
    generation = build_generation
    generation.save!
    expect(generation.account_id).to eq(campaign.account_id)
    expect(generation).to be_queued
  end

  it 'requires a content item for variant generation' do
    expect(build_generation(kind: :variants)).not_to be_valid
    expect(build_generation(kind: :variants, content_item: item)).to be_valid
  end

  it 'requires a content variant for rewrite and suggestions' do
    expect(build_generation(kind: :rewrite)).not_to be_valid
    expect(build_generation(kind: :suggestions, content_variant: variant)).to be_valid
  end

  it 'rejects targets from another campaign' do
    other_item = create(:glint_reach_content_item)
    other_variant = create(:glint_reach_content_variant, content_item: other_item)

    by_item = build_generation(kind: :variants, content_item: other_item)
    by_variant = build_generation(kind: :rewrite, content_variant: other_variant)

    expect(by_item).not_to be_valid
    expect(by_item.errors.attribute_names).to include(:content_item)
    expect(by_variant).not_to be_valid
    expect(by_variant.errors.attribute_names).to include(:content_variant)
  end

  it 'rejects unknown kinds' do
    expect(build_generation(kind: 'publish')).not_to be_valid
  end

  it 'records completion usage and failure details' do
    generation = build_generation
    generation.save!
    generation.mark_generating!
    response = GlintReach::Ai::Response.new(payload: {}, provider: 'openai', model: 'gpt-test',
                                            usage: { input_tokens: 10, output_tokens: 5, credit_multiplier: 2 })
    generation.mark_completed!(result: { 'ok' => true }, response: response)
    expect(generation.reload).to have_attributes(status: 'completed', provider: 'openai', model: 'gpt-test',
                                                 input_tokens: 10, output_tokens: 5, result: { 'ok' => true })

    generation.mark_failed!(code: 'refused', message: 'x' * 900)
    expect(generation.reload.error_message.length).to eq(500)
  end

  it 'is deleted with its campaign' do
    build_generation.save!
    expect { campaign.destroy! }.to change(described_class, :count).by(-1)
  end
end
