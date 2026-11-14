require 'rails_helper'

RSpec.describe GlintReach::ContentVariant do
  let(:content_item) { create(:glint_reach_content_item) }

  it 'derives account_id from its content item' do
    expect(create(:glint_reach_content_variant, content_item: content_item).account_id).to eq(content_item.account_id)
  end

  it 'allows one variant per platform per content item' do
    create(:glint_reach_content_variant, content_item: content_item, platform: :linkedin)
    duplicate = build(:glint_reach_content_variant, content_item: content_item, platform: :linkedin)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:platform]).to be_present
  end

  it 'rejects an unknown platform' do
    expect(build(:glint_reach_content_variant, content_item: content_item, platform: 'myspace')).not_to be_valid
  end

  it 'normalizes hashtags' do
    variant = create(:glint_reach_content_variant, content_item: content_item, hashtags: ['#Launch', ' launch2 ', '', '#Launch'])

    expect(variant.hashtags).to eq(%w[Launch launch2])
  end

  it 'rejects invalid or too many hashtags' do
    expect(build(:glint_reach_content_variant, content_item: content_item, hashtags: ['two words'])).not_to be_valid
    expect(build(:glint_reach_content_variant, content_item: content_item, hashtags: (1..31).map { |i| "tag#{i}" })).not_to be_valid
  end

  it 'exposes the workflow transition table' do
    variant = create(:glint_reach_content_variant, content_item: content_item)

    expect(variant.can_transition_to?(:in_review)).to be(true)
    expect(variant.can_transition_to?(:approved)).to be(false)
    expect(variant.can_transition_to?(:scheduled)).to be(false)
  end

  it 'only allows content changes while draft or changes requested' do
    variant = create(:glint_reach_content_variant, content_item: content_item)
    variant.update_columns(status: described_class.statuses[:approved]) # rubocop:disable Rails/SkipsModelValidations
    variant.reload

    expect(variant.update(body: 'Changed')).to be(false)
    expect(variant.errors[:base].join).to include('Move it back to draft')
    variant.reload
    expect(variant.update(status: :scheduled)).to be(true)
  end

  it 'changes the content digest when reviewed content changes' do
    variant = create(:glint_reach_content_variant, content_item: content_item)
    digest = variant.content_digest
    variant.update!(hashtags: ['new'])
    expect(variant.content_digest).not_to eq(digest)
  end
end
