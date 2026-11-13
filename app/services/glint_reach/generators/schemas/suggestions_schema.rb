class GlintReach::Generators::Schemas::SuggestionsSchema < Schematist::Schema
  array :hashtags, description: 'Relevant hashtags without the # sign, most relevant first.', max_items: 15 do
    string pattern: GlintReach::Generation::HASHTAG_PATTERN, max_length: 100
  end
  array :calls_to_action, description: 'Short calls to action, most suitable first.', max_items: 5 do
    string min_length: 1, max_length: 100
  end
end
