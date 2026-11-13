# Validates a generation request and queues it. Rejections raise Rejected with an i18n key so the API
# can return an actionable 422. Checks run before anything is queued, so the UI never shows a
# "queued" state for work that cannot succeed.
class GlintReach::Generators::Enqueuer
  class Rejected < StandardError; end

  STALE_AFTER = 10.minutes

  def initialize(campaign:, user:, params:)
    @campaign = campaign
    @user = user
    @params = params
  end

  def perform
    reject!(:campaign_locked) if @campaign.locked?
    reject!(:not_configured) unless GlintReach::Ai::ProviderResolver.configured?(@campaign.account)

    generation = build
    reject!(:invalid_request) unless generation.valid?
    check_target!(generation)

    @campaign.with_lock do
      expire_stale!(generation)
      reject!(:already_running) if GlintReach::Generation.active.exists?(generation.target_scope)
      generation.save!
    end
    GlintReach::GenerationJob.perform_later(generation.id)
    generation
  end

  private

  def build
    @campaign.generations.new(
      requested_by: @user,
      kind: @params[:kind],
      content_item: find_item,
      content_variant: find_variant,
      options: request_options
    )
  end

  # Lookups go through the campaign so IDs from another campaign/account resolve to nil (-> invalid).
  def find_item
    return if @params[:content_item_id].blank?

    @campaign.content_items.find_by(id: @params[:content_item_id])
  end

  def find_variant
    return if @params[:content_variant_id].blank?

    GlintReach::ContentVariant.joins(:content_item)
                              .where(glint_reach_content_items: { campaign_id: @campaign.id })
                              .find_by(id: @params[:content_variant_id])
  end

  def request_options
    {
      'platforms' => Array(@params[:platforms]).map(&:to_s) & GlintReach::ContentVariant.platforms.keys,
      'count' => @params[:count].presence&.to_i,
      'instruction' => @params[:instruction].to_s.strip.presence
    }.compact_blank
  end

  def check_target!(generation)
    instruction = generation.options['instruction'].to_s
    reject!(:instruction_too_long) if instruction.length > GlintReach::Generation::MAX_INSTRUCTION_LENGTH
    check_rewrite!(generation, instruction) if generation.rewrite?
    reject!(:content_item_missing) if generation.variants? && generation.content_item.archived?
  end

  def check_rewrite!(generation, instruction)
    reject!(:instruction_required) if instruction.blank?
    reject!(:variant_approved) if generation.content_variant.ready?
  end

  def expire_stale!(generation)
    GlintReach::Generation.where(generation.target_scope).generating.where(started_at: ...STALE_AFTER.ago).find_each do |stale|
      stale.mark_failed!(code: 'timeout', message: I18n.t('errors.glint_reach.ai.timeout'))
    end
  end

  def reject!(key)
    raise Rejected, I18n.t("errors.glint_reach.ai.#{key}")
  end
end
