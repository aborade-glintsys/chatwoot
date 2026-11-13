# Suggests hashtags and CTAs for one variant. Suggestions are returned, not applied: the user picks
# which ones to add, so nothing on the variant changes here.
class GlintReach::Generators::SuggestionsGenerator < GlintReach::Generators::Base
  private

  def schema = GlintReach::Generators::Schemas::SuggestionsSchema
  def variant = generation.content_variant

  def context_blocks
    context.blocks(content_item: variant.content_item, variant: variant)
  end

  def task_prompt
    "Task: suggest hashtags and calls to action for current_variant on #{variant.platform}. " \
      'Prefer the brand approved_ctas when present. Do not repeat hashtags already used.'
  end

  def persist!(payload)
    used = variant.hashtags.map(&:downcase)
    hashtags = payload['hashtags'].uniq(&:downcase).reject { |tag| used.include?(tag.downcase) }
    { 'hashtags' => hashtags, 'calls_to_action' => payload['calls_to_action'].uniq }
  end
end
