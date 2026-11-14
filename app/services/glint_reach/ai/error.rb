# Provider-neutral error taxonomy. Adapters translate vendor exceptions into the subclasses in
# app/services/glint_reach/ai/error/, so campaign workflows never depend on a specific SDK.
# `code` is stored on the generation and drives the UI copy; `retryable?` decides whether the job retries.
class GlintReach::Ai::Error < StandardError
  def code = self.class.name.demodulize.underscore
  def retryable? = false
end
