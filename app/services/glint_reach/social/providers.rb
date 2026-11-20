# Registry of social providers supported by GlintReach.
module GlintReach::Social::Providers
  REGISTRY = {
    'linkedin' => 'GlintReach::Social::Providers::Linkedin'
  }.freeze

  class << self
    def keys
      REGISTRY.keys
    end

    def all
      REGISTRY.keys.map { |key| build(key) }
    end

    def build(key)
      class_name = REGISTRY[key.to_s]
      raise GlintReach::Social::Error::NotConfigured, I18n.t('errors.glint_reach.social.unknown_provider') unless class_name

      class_name.constantize.new
    end
  end
end
