# Drafts one variant per requested platform. Existing editable (draft / changes requested) variants are overwritten; variants
# that are no longer editable (in review, approved, scheduled or later) are skipped and reported.
class GlintReach::Generators::VariantsGenerator < GlintReach::Generators::Base
  private

  def schema = GlintReach::Generators::Schemas::VariantsSchema
  def content_item = generation.content_item

  def context_blocks
    context.blocks(content_item: content_item, include_strategy: true)
  end

  def task_prompt
    "Task: write one post draft for each of these platforms: #{requested_platforms.join(', ')}. " \
      "Respect each platform's conventions and typical length. Use approved_ctas for call_to_action when they fit."
  end

  def persist!(payload)
    ensure_item_writable!
    drafts = payload['variants'].index_by { |variant| variant['platform'] }
    result = { 'variant_ids' => [], 'skipped_platforms' => [] }
    requested_platforms.each do |platform|
      next if drafts[platform].nil?

      variant = save_draft(platform, drafts[platform])
      variant ? result['variant_ids'] << variant.id : result['skipped_platforms'] << platform
    end
    raise GlintReach::Ai::Error::InvalidResponse, 'no drafts for the requested platforms' if result.values.all?(&:empty?)

    result
  end

  def ensure_item_writable!
    raise TargetLocked, 'content_item_missing' if content_item.nil? || content_item.archived?
  end

  # Returns nil when the existing variant is past editing (in review, approved, scheduled...).
  def save_draft(platform, draft)
    variant = content_item.variants.lock.find_or_initialize_by(platform: platform)
    return if variant.persisted? && !variant.editable?

    variant.update!(body: draft['body'], call_to_action: draft['call_to_action'].presence,
                    hashtags: draft['hashtags'], generation: generation)
    variant
  end
end
