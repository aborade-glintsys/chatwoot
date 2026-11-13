class GlintReach::Generators::Schemas::VariantsSchema < Schematist::Schema
  array :variants, description: 'One draft per requested platform.', min_items: 1,
                   max_items: GlintReach::ContentVariant.platforms.size do
    object do
      string :platform, enum: GlintReach::ContentVariant.platforms.keys
      string :body, description: 'Post text written for this platform.', min_length: 1,
                    max_length: GlintReach::Generation::MAX_BODY_LENGTH
      string :call_to_action, description: 'Short call to action, or empty string.', max_length: 255
      array :hashtags, description: 'Hashtags without the # sign.', max_items: 10 do
        string pattern: GlintReach::Generation::HASHTAG_PATTERN, max_length: 100
      end
    end
  end
end
