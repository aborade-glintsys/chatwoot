# Registry of platform publishers. Empty until social publishing is implemented in a later phase, so
# every due schedule fails revalidation with `publisher_unavailable` and nothing is sent anywhere.
module GlintReach::Publishers
  REGISTRY = {}.freeze

  def self.available?(platform, _account)
    REGISTRY.key?(platform.to_s)
  end
end
