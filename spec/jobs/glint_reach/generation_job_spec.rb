require 'rails_helper'

RSpec.describe GlintReach::GenerationJob do
  let(:account) { create(:account) }
  let(:campaign) { create(:glint_reach_campaign, account: account) }
  let(:generation) { campaign.generations.create!(requested_by: campaign.created_by, kind: :suggestions, content_variant: variant) }
  let(:variant) { create(:glint_reach_content_variant, content_item: create(:glint_reach_content_item, campaign: campaign)) }
  let(:payload) { { 'hashtags' => ['spring'], 'calls_to_action' => ['Shop now'] } }

  before { account.enable_features!(:glint_reach) }

  def stub_client(client)
    allow(GlintReach::Ai::ProviderResolver).to receive(:client_for).and_return(client)
  end

  it 'completes a queued generation' do
    stub_client(GlintReachFakeAiClient.new(payload: payload))
    described_class.perform_now(generation.id)

    expect(generation.reload).to have_attributes(status: 'completed', result: hash_including('hashtags' => ['spring']))
  end

  it 'ignores generations that are not queued (idempotent)' do
    client = GlintReachFakeAiClient.new(payload: payload)
    stub_client(client)
    generation.update!(status: :completed)

    described_class.perform_now(generation.id)
    expect(client.requests).to be_empty
  end

  it 'ignores missing records' do
    expect { described_class.perform_now(0) }.not_to raise_error
  end

  it 'stores an actionable failure when AI is not configured' do
    allow(GlintReach::Ai::ProviderResolver).to receive(:client_for)
      .and_raise(GlintReach::Ai::Error::NotConfigured, 'no key')
    described_class.perform_now(generation.id)

    expect(generation.reload).to have_attributes(status: 'failed', error_code: 'not_configured')
    expect(generation.error_message).to include('Captain settings')
  end

  it 'fails without calling the provider when GlintReach is disabled' do
    account.disable_features!(:glint_reach)
    client = GlintReachFakeAiClient.new(payload: payload)
    stub_client(client)
    described_class.perform_now(generation.id)

    expect(generation.reload.error_code).to eq('glint_reach_disabled')
    expect(client.requests).to be_empty
  end

  it 're-queues and retries retryable errors' do
    stub_client(GlintReachFakeAiClient.new(error: GlintReach::Ai::Error::RateLimited.new('slow down')))

    expect { described_class.perform_now(generation.id) }.to have_enqueued_job(described_class).with(generation.id)
    expect(generation.reload).to be_queued
  end

  it 'fails after the maximum attempts for retryable errors' do
    stub_client(GlintReachFakeAiClient.new(error: GlintReach::Ai::Error::Unavailable.new('down')))
    job = described_class.new(generation.id)
    job.executions = described_class::MAX_ATTEMPTS
    allow(job).to receive(:executions).and_return(described_class::MAX_ATTEMPTS)
    job.perform(generation.id)

    expect(generation.reload).to have_attributes(status: 'failed', error_code: 'unavailable')
  end

  it 'stores schema failures without a false success' do
    stub_client(GlintReachFakeAiClient.new(payload: { 'hashtags' => 'oops' }))
    described_class.perform_now(generation.id)

    expect(generation.reload).to have_attributes(status: 'failed', error_code: 'invalid_response', result: be_blank)
  end

  it 'reports unexpected errors and stores a generic failure' do
    stub_client(GlintReachFakeAiClient.new(error: ArgumentError.new('bug')))
    tracker = instance_double(ChatwootExceptionTracker, capture_exception: true)
    allow(ChatwootExceptionTracker).to receive(:new).and_return(tracker)
    described_class.perform_now(generation.id)

    expect(generation.reload.error_code).to eq('unexpected')
    expect(tracker).to have_received(:capture_exception)
  end
end
