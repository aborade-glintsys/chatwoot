require 'rails_helper'

# Optional integration test against the real provider. Skipped unless explicitly enabled:
#   GLINT_REACH_LIVE_AI=1 GLINT_REACH_OPENAI_KEY=sk-... bundle exec rspec spec/services/glint_reach/ai/provider_resolver_live_spec.rb
# It makes one small paid request.
RSpec.describe GlintReach::Ai::ProviderResolver, :live_ai do
  let(:api_key) { ENV.fetch('GLINT_REACH_OPENAI_KEY', nil) }

  before do
    skip 'set GLINT_REACH_LIVE_AI=1 and GLINT_REACH_OPENAI_KEY to run' unless ENV['GLINT_REACH_LIVE_AI'] == '1' && api_key.present?
    InstallationConfig.where(name: 'CAPTAIN_OPEN_AI_API_KEY').first_or_create!(value: api_key)
    WebMock.allow_net_connect!
  end

  after { WebMock.disable_net_connect!(allow_localhost: true) }

  it 'returns schema-valid suggestions from the configured provider' do
    campaign = create(:glint_reach_campaign, name: 'Spring hiking gear launch', channels: %w[instagram])
    item = create(:glint_reach_content_item, campaign: campaign)
    variant = create(:glint_reach_content_variant, content_item: item, body: 'New trail shoes are here.')
    generation = campaign.generations.create!(requested_by: campaign.created_by, kind: :suggestions,
                                              content_variant: variant, status: :generating)

    GlintReach::Generators::SuggestionsGenerator.new(generation: generation, client: described_class.client_for(campaign.account)).perform

    expect(generation.reload).to be_completed
    expect(generation.result['hashtags']).to all(match(/\A[A-Za-z0-9_]+\z/))
    expect(generation.input_tokens).to be_positive
  end
end
