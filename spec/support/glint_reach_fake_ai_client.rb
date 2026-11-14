# Deterministic stand-in for a GlintReach AI provider adapter. Responds to `generate(request)` like a
# real adapter, records requests, and either returns the given payload or raises the given error.
# Used so GlintReach specs never make network or paid AI calls.
class GlintReachFakeAiClient
  attr_reader :requests

  def initialize(payload: nil, error: nil, usage: { input_tokens: 120, output_tokens: 80, credit_multiplier: 1 })
    @payload = payload
    @error = error
    @usage = usage
    @requests = []
  end

  def generate(request)
    @requests << request
    raise @error if @error

    GlintReach::Ai::Response.new(payload: @payload, provider: 'openai', model: 'gpt-test', usage: @usage)
  end
end
