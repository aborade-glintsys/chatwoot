# The only GlintReach file that knows about ruby_llm. Translates a provider-neutral Request into a
# structured-output chat call and maps every vendor failure onto GlintReach::Ai::Error.
class GlintReach::Ai::Adapters::RubyLlm
  REQUEST_TIMEOUT = 60
  MAX_RETRIES = 1
  REFUSAL_PATTERN = /\b(i can(?:'|no)?t|i(?:'m| am) (?:unable|not able)|i won'?t) (?:help|assist|comply|do that|create)/i

  attr_reader :provider, :model

  def initialize(provider:, model:, api_key:)
    @provider = provider
    @model = model
    @api_key = api_key
  end

  def generate(request)
    message = build_chat(request).ask(request.user_content)
    GlintReach::Ai::Response.new(payload: parse(message), provider: provider, model: model, usage: usage_for(message))
  rescue GlintReach::Ai::Error
    raise
  rescue StandardError => e
    raise translate(e)
  end

  private

  def build_chat(request)
    Llm::Config.initialize!
    options = Captain::ResponsesConfig.options(model: model, temperature: nil, feature: request.feature)
    chat = context.chat(model: model, **options.slice(:protocol))
    chat.with_thinking(**options[:thinking]) if options[:thinking]
    chat.with_instructions(request.system_prompt)
    chat.with_schema(request.schema)
  end

  def context
    RubyLLM.context do |config|
      config.openai_api_key = @api_key
      config.openai_api_base = api_base
      config.request_timeout = REQUEST_TIMEOUT
      config.max_retries = MAX_RETRIES
    end
  end

  def api_base
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence || LlmConstants::OPENAI_API_ENDPOINT
    "#{endpoint.chomp('/')}/v1"
  end

  def parse(message)
    raise GlintReach::Ai::Error::Refused, 'content_filter' if message.respond_to?(:content_filtered?) && message.content_filtered?

    content = message.content
    return content if content.is_a?(Hash) && content.present?

    parse_json(content.to_s)
  end

  def parse_json(text)
    raise GlintReach::Ai::Error::InvalidResponse, 'empty response' if text.blank?

    parsed = JSON.parse(text)
    raise GlintReach::Ai::Error::InvalidResponse, 'response is not a JSON object' unless parsed.is_a?(Hash)

    parsed
  rescue JSON::ParserError
    raise GlintReach::Ai::Error::Refused, 'model declined' if text.match?(REFUSAL_PATTERN)

    raise GlintReach::Ai::Error::InvalidResponse, 'malformed JSON'
  end

  def usage_for(message)
    tokens = message.respond_to?(:tokens) ? message.tokens : nil
    {
      input_tokens: tokens&.input,
      output_tokens: tokens&.output,
      credit_multiplier: Llm::Models.model_config(model)&.dig('credit_multiplier')
    }
  end

  def translate(error)
    case error
    when RubyLLM::RateLimitError then GlintReach::Ai::Error::RateLimited.new(error.message)
    when RubyLLM::PaymentRequiredError then GlintReach::Ai::Error::QuotaExceeded.new(error.message)
    when RubyLLM::ContextLengthExceededError then GlintReach::Ai::Error::InputTooLarge.new(error.message)
    when RubyLLM::UnauthorizedError, RubyLLM::ForbiddenError, RubyLLM::ModelNotFoundError, RubyLLM::ConfigurationError
      GlintReach::Ai::Error::NotConfigured.new(error.message)
    when RubyLLM::BadRequestError then GlintReach::Ai::Error::InvalidRequest.new(error.message)
    when RubyLLM::Error, Faraday::Error, Timeout::Error, Errno::ECONNREFUSED, SocketError
      GlintReach::Ai::Error::Unavailable.new(error.message)
    else
      raise error
    end
  end
end
