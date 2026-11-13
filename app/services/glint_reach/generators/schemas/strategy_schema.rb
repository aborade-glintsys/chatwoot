class GlintReach::Generators::Schemas::StrategySchema < Schematist::Schema
  PLATFORMS = GlintReach::ContentVariant.platforms.keys

  string :positioning, description: 'One paragraph on how the campaign should position the offer for the audience.',
                       min_length: 1, max_length: 600
  array :key_messages, description: 'The most important messages, most important first.', min_items: 1, max_items: 5 do
    string min_length: 1, max_length: 300
  end
  array :content_pillars, description: 'Recurring themes the content should cover.', min_items: 1, max_items: 5 do
    object do
      string :name, min_length: 1, max_length: 80
      string :description, min_length: 1, max_length: 300
    end
  end
  array :channel_approach, description: 'How to use each requested channel. Only the channels listed in the brief.',
                           max_items: PLATFORMS.size do
    object do
      string :platform, enum: PLATFORMS
      string :approach, min_length: 1, max_length: 400
    end
  end
end
