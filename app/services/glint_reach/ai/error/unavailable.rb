# Timeouts, 5xx, overload or network failures.
class GlintReach::Ai::Error::Unavailable < GlintReach::Ai::Error
  def retryable? = true
end
