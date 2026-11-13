# Rewrites a single draft variant following the user's instruction. Approved (ready) variants are refused.
class GlintReach::Generators::RewriteGenerator < GlintReach::Generators::Base
  private

  def schema = GlintReach::Generators::Schemas::RewriteSchema
  def variant = generation.content_variant

  def context_blocks
    context.blocks(content_item: variant.content_item, variant: variant, instruction: options['instruction'])
  end

  def task_prompt
    "Task: rewrite current_variant for #{variant.platform} following user_instruction. " \
      'Keep the facts. Return the full rewritten post.'
  end

  def persist!(payload)
    variant.lock!
    raise TargetLocked, 'variant_approved' if variant.ready?

    previous = variant.body
    variant.update!(body: payload['body'], call_to_action: payload['call_to_action'].presence,
                    hashtags: payload['hashtags'], generation: generation)
    { 'variant_ids' => [variant.id], 'previous_body' => previous.to_s.truncate(GlintReach::Generation::MAX_BODY_LENGTH) }
  end
end
