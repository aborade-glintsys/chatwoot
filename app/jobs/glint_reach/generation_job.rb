# Runs one queued generation. Idempotent: only a `queued` record is picked up, so duplicate deliveries
# are no-ops. Transient provider errors (rate limit, outage) are retried with backoff up to
# MAX_ATTEMPTS; every other failure is stored on the record with an actionable message.
class GlintReach::GenerationJob < ApplicationJob
  queue_as :medium

  MAX_ATTEMPTS = 3
  GENERATORS = {
    'strategy' => 'GlintReach::Generators::StrategyGenerator',
    'content_plan' => 'GlintReach::Generators::ContentPlanGenerator',
    'content_item' => 'GlintReach::Generators::ContentItemGenerator',
    'variants' => 'GlintReach::Generators::VariantsGenerator',
    'rewrite' => 'GlintReach::Generators::RewriteGenerator',
    'suggestions' => 'GlintReach::Generators::SuggestionsGenerator'
  }.freeze

  def perform(generation_id)
    generation = GlintReach::Generation.find_by(id: generation_id)
    return unless claim(generation)

    run(generation)
  end

  private

  def claim(generation)
    return false if generation.nil?

    generation.with_lock do
      next false unless generation.queued?

      generation.mark_generating!
      true
    end
  end

  def run(generation)
    return fail!(generation, 'glint_reach_disabled') unless generation.account.feature_enabled?(:glint_reach)

    client = GlintReach::Ai::ProviderResolver.client_for(generation.account)
    GENERATORS.fetch(generation.kind).constantize.new(generation: generation, client: client).perform
  rescue GlintReach::Ai::Error => e
    handle_ai_error(generation, e)
  rescue GlintReach::Generators::Base::TargetLocked => e
    fail!(generation, e.message)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: generation.account).capture_exception
    fail!(generation, 'unexpected')
  end

  def handle_ai_error(generation, error)
    Rails.logger.warn("[GlintReach] generation=#{generation.id} #{error.class}: #{error.message.to_s.truncate(200)}")
    if error.retryable? && executions < MAX_ATTEMPTS
      generation.update!(status: :queued)
      retry_job(wait: (2**executions).seconds * 5)
    else
      fail!(generation, error.code)
    end
  end

  def fail!(generation, code)
    generation.mark_failed!(code: code, message: I18n.t("errors.glint_reach.ai.#{code}", default: I18n.t('errors.glint_reach.ai.unexpected')))
  end
end
