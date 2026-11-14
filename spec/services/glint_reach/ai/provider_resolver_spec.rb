require 'rails_helper'

RSpec.describe GlintReach::Ai::ProviderResolver do
  let(:account) { create(:account) }

  it 'raises NotConfigured when no OpenAI key is stored (no mock fallback)' do
    InstallationConfig.where(name: 'CAPTAIN_OPEN_AI_API_KEY').destroy_all

    expect { described_class.client_for(account) }.to raise_error(GlintReach::Ai::Error::NotConfigured, /not configured/)
    expect(described_class.configured?(account)).to be(false)
  end

  it 'returns the adapter for the configured provider and model' do
    InstallationConfig.where(name: 'CAPTAIN_OPEN_AI_API_KEY').first_or_create!(value: 'sk-test')

    client = described_class.client_for(account)
    expect(client).to be_a(GlintReach::Ai::Adapters::RubyLlm)
    expect(client.provider).to eq('openai')
    expect(client.model).to be_present
    expect(described_class.configured?(account)).to be(true)
  end
end
