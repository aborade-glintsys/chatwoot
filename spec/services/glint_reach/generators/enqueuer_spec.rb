require 'rails_helper'

RSpec.describe GlintReach::Generators::Enqueuer do
  let(:account) { create(:account) }
  let(:campaign) { create(:glint_reach_campaign, account: account) }
  let(:user) { campaign.created_by }
  let(:item) { create(:glint_reach_content_item, campaign: campaign) }
  let(:variant) { create(:glint_reach_content_variant, content_item: item) }

  def enqueue(params)
    described_class.new(campaign: campaign, user: user, params: params).perform
  end

  before { allow(GlintReach::Ai::ProviderResolver).to receive(:configured?).and_return(true) }

  it 'queues a generation and the job' do
    generation = nil
    expect { generation = enqueue(kind: 'strategy') }.to have_enqueued_job(GlintReach::GenerationJob)
    expect(generation).to have_attributes(status: 'queued', account_id: account.id, requested_by_id: user.id)
  end

  it 'keeps only known platforms and clean options' do
    generation = enqueue(kind: 'variants', content_item_id: item.id, platforms: %w[instagram myspace], instruction: '  ')
    expect(generation.options).to eq('platforms' => ['instagram'])
  end

  it 'rejects when AI is not configured' do
    allow(GlintReach::Ai::ProviderResolver).to receive(:configured?).and_return(false)
    expect { enqueue(kind: 'strategy') }.to raise_error(described_class::Rejected, /not configured/)
    expect(GlintReach::Generation.count).to eq(0)
  end

  it 'rejects locked campaigns' do
    campaign.update_columns(status: GlintReach::Campaign.statuses[:archived]) # rubocop:disable Rails/SkipsModelValidations -- simulate a campaign locked after queuing
    expect { enqueue(kind: 'strategy') }.to raise_error(described_class::Rejected, /can no longer be edited/)
  end

  it 'rejects unknown kinds and targets from another campaign' do
    other_item = create(:glint_reach_content_item)
    expect { enqueue(kind: 'publish') }.to raise_error(described_class::Rejected)
    expect { enqueue(kind: 'variants', content_item_id: other_item.id) }.to raise_error(described_class::Rejected)
  end

  it 'validates rewrite instructions' do
    expect { enqueue(kind: 'rewrite', content_variant_id: variant.id) }.to raise_error(described_class::Rejected, /Enter an instruction/)
    expect { enqueue(kind: 'rewrite', content_variant_id: variant.id, instruction: 'a' * 501) }
      .to raise_error(described_class::Rejected, /500 characters/)
  end

  it 'rejects rewrites of approved variants' do
    variant.update!(status: :ready)
    expect { enqueue(kind: 'rewrite', content_variant_id: variant.id, instruction: 'Shorter') }
      .to raise_error(described_class::Rejected, /marked ready/)
  end

  it 'rejects a duplicate active generation for the same target' do
    enqueue(kind: 'strategy')
    expect { enqueue(kind: 'strategy') }.to raise_error(described_class::Rejected, /already in progress/)
  end

  it 'expires stale generating records so the user can retry' do
    stale = enqueue(kind: 'strategy')
    stale.update!(status: :generating, started_at: 11.minutes.ago)

    expect(enqueue(kind: 'strategy')).to be_queued
    expect(stale.reload).to have_attributes(status: 'failed', error_code: 'timeout')
  end
end
