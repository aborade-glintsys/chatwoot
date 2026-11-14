class GlintReach::Generators::StrategyGenerator < GlintReach::Generators::Base
  private

  def schema = GlintReach::Generators::Schemas::StrategySchema

  def task_prompt
    'Task: write a campaign strategy for the brief. Cover only the channels listed in the brief ' \
      '(if none are listed, give a general approach and leave channel_approach empty).'
  end

  def persist!(payload)
    campaign.update!(strategy: payload)
    { 'key_messages' => payload['key_messages'].size, 'content_pillars' => payload['content_pillars'].size }
  end
end
