# Provider is throttling requests.
class GlintReach::Ai::Error::RateLimited < GlintReach::Ai::Error
  def retryable? = true
end
