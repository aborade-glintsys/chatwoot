class GlintReach::Generators::ContentPlanGenerator < GlintReach::Generators::Base
  DEFAULT_COUNT = 5

  private

  def schema = GlintReach::Generators::Schemas::ContentPlanSchema
  def context_blocks = context.blocks(include_strategy: true)

  def count
    value = options['count'].to_i
    value.positive? ? value.clamp(1, GlintReach::Generation::MAX_PLAN_ITEMS) : DEFAULT_COUNT
  end

  def task_prompt
    "Task: plan exactly #{count} distinct content pieces for this campaign that together serve its objective. " \
      'Vary the angles and content types.'
  end

  # Always adds new draft items; existing content is never modified.
  def persist!(payload)
    items = payload['items'].first(count).map do |item|
      campaign.content_items.create!(title: item['title'], content_type: item['content_type'], generation: generation)
    end
    { 'content_item_ids' => items.map(&:id), 'angles' => payload['items'].first(count).pluck('angle') }
  end
end
