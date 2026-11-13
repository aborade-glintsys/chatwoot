class GlintReach::Generators::Schemas::ContentPlanSchema < Schematist::Schema
  array :items, description: 'Planned content pieces for the campaign.', min_items: 1,
                max_items: GlintReach::Generation::MAX_PLAN_ITEMS do
    object do
      string :title, description: 'Short working title.', min_length: 1, max_length: 255
      string :content_type, enum: GlintReach::ContentItem.content_types.keys
      string :angle, description: 'What this piece says and why it serves the objective.', min_length: 1, max_length: 500
    end
  end
end
