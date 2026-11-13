class GlintReach::Generators::Schemas::ContentItemSchema < Schematist::Schema
  string :title, description: 'Short working title.', min_length: 1, max_length: 255
  string :content_type, enum: GlintReach::ContentItem.content_types.keys
  string :angle, description: 'What this piece says and why it serves the objective.', min_length: 1, max_length: 500
end
