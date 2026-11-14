# Picks the AI client for an account. The model comes from config/llm.yml through Llm::FeatureRouter
# (so per-account overrides keep working); the provider is derived from the model. A client is only
# returned when a real credential for that provider exists – otherwise NotConfigured is raised.
# There is deliberately no mock/demo fallback.
#
# Adding a vendor: implement an adapter with `#generate(request) -> Response`, then register its
# credential lookup and adapter below. Campaign services do not change.
module GlintReach::Ai::ProviderResolver
  FEATURE = 'glint_reach_generation'.freeze

  CREDENTIALS = {
    'openai' => -> { InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value.presence }
  }.freeze

  ADAPTERS = {
    'openai' => 'GlintReach::Ai::Adapters::RubyLlm'
  }.freeze

  class << self
    def client_for(account)
      route = Llm::FeatureRouter.resolve(feature: FEATURE, account: account)
      provider = route[:provider].to_s
      api_key = CREDENTIALS[provider]&.call
      raise GlintReach::Ai::Error::NotConfigured, I18n.t('errors.glint_reach.ai.not_configured') if api_key.blank? || !ADAPTERS.key?(provider)

      ADAPTERS.fetch(provider).constantize.new(provider: provider, model: route[:model], api_key: api_key)
    end

    def configured?(account)
      client_for(account)
      true
    rescue GlintReach::Ai::Error::NotConfigured
      false
    end
  end
end
