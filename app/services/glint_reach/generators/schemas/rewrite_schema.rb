class GlintReach::Generators::Schemas::RewriteSchema < Schematist::Schema
  string :body, description: 'The rewritten post text.', min_length: 1, max_length: GlintReach::Generation::MAX_BODY_LENGTH
  string :call_to_action, description: 'Short call to action, or empty string.', max_length: 255
  array :hashtags, description: 'Hashtags without the # sign.', max_items: 10 do
    string pattern: GlintReach::Generation::HASHTAG_PATTERN, max_length: 100
  end
end
