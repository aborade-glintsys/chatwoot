require 'rails_helper'

RSpec.describe GlintReach::Ai::Adapters::RubyLlm do
  let(:adapter) { described_class.new(provider: 'openai', model: 'gpt-5-mini', api_key: 'sk-test') }
  let(:request) do
    GlintReach::Ai::Request.new(system_prompt: 'sys', user_content: 'data', schema: GlintReach::Generators::Schemas::SuggestionsSchema,
                                feature: 'glint_reach_generation')
  end
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:tokens) { Struct.new(:input, :output).new(11, 7) }

  def message(content, filtered: false)
    instance_double(RubyLLM::Message, content: content, tokens: tokens, content_filtered?: filtered)
  end

  before { allow(adapter).to receive(:build_chat).and_return(chat) }

  it 'returns a parsed payload with usage' do
    allow(chat).to receive(:ask).with('data').and_return(message({ 'hashtags' => [], 'calls_to_action' => [] }))

    response = adapter.generate(request)
    expect(response.payload).to eq('hashtags' => [], 'calls_to_action' => [])
    expect(response.usage).to include(input_tokens: 11, output_tokens: 7)
    expect(response).to have_attributes(provider: 'openai', model: 'gpt-5-mini')
  end

  it 'parses JSON strings' do
    allow(chat).to receive(:ask).and_return(message('{"hashtags":["a"]}'))
    expect(adapter.generate(request).payload).to eq('hashtags' => ['a'])
  end

  {
    'empty' => ['', GlintReach::Ai::Error::InvalidResponse],
    'malformed' => ['{"hashtags": [', GlintReach::Ai::Error::InvalidResponse],
    'non-object' => ['[1,2]', GlintReach::Ai::Error::InvalidResponse],
    'refusal text' => ["I can't help with that request.", GlintReach::Ai::Error::Refused]
  }.each do |label, (content, error)|
    it "maps #{label} responses to #{error.name.demodulize}" do
      allow(chat).to receive(:ask).and_return(message(content))
      expect { adapter.generate(request) }.to raise_error(error)
    end
  end

  it 'maps filtered content to Refused' do
    allow(chat).to receive(:ask).and_return(message('{}', filtered: true))
    expect { adapter.generate(request) }.to raise_error(GlintReach::Ai::Error::Refused)
  end

  {
    RubyLLM::RateLimitError => GlintReach::Ai::Error::RateLimited,
    RubyLLM::ServiceUnavailableError => GlintReach::Ai::Error::Unavailable,
    RubyLLM::ServerError => GlintReach::Ai::Error::Unavailable,
    RubyLLM::PaymentRequiredError => GlintReach::Ai::Error::QuotaExceeded,
    RubyLLM::ContextLengthExceededError => GlintReach::Ai::Error::InputTooLarge,
    RubyLLM::UnauthorizedError => GlintReach::Ai::Error::NotConfigured,
    RubyLLM::BadRequestError => GlintReach::Ai::Error::InvalidRequest
  }.each do |vendor_error, mapped|
    it "maps #{vendor_error.name} to #{mapped.name.demodulize}" do
      allow(chat).to receive(:ask).and_raise(vendor_error.new('boom'))
      expect { adapter.generate(request) }.to raise_error(mapped)
    end
  end

  it 'maps network timeouts to Unavailable' do
    allow(chat).to receive(:ask).and_raise(Faraday::TimeoutError)
    expect { adapter.generate(request) }.to raise_error(GlintReach::Ai::Error::Unavailable)
  end

  it 'does not swallow programming errors' do
    allow(chat).to receive(:ask).and_raise(NoMethodError)
    expect { adapter.generate(request) }.to raise_error(NoMethodError)
  end
end
