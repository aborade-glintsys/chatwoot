class GlintReach::Generators::ContentItemGenerator < GlintReach::Generators::Base
  private

  def schema = GlintReach::Generators::Schemas::ContentItemSchema

  def context_blocks
    context.blocks(include_strategy: true, instruction: options['instruction'])
  end

  def task_prompt
    'Task: propose one new content piece for this campaign. If a user_instruction is present, base the piece on that idea.'
  end

  def persist!(payload)
    item = campaign.content_items.create!(title: payload['title'], content_type: payload['content_type'], generation: generation)
    { 'content_item_ids' => [item.id], 'angle' => payload['angle'] }
  end
end
