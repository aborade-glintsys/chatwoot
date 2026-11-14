# Builds the untrusted-data part of a prompt (see docs/glintreach/ai-inputs.md). Only fields relevant
# to content generation are included, each block is JSON inside a fixed tag, and tag-like strings are
# stripped from values so user text cannot close a block early. The system prompt tells the model to
# treat everything inside these tags as data.
class GlintReach::Generators::ContextBuilder
  TAGS = %w[brand_profile campaign_brief campaign_strategy content_item current_variant user_instruction].freeze
  TAG_PATTERN = %r{</?\s*(?:#{TAGS.join('|')})\s*>}i

  BRAND_FIELDS = %w[name description website_url products_services target_audience geographic_market preferred_languages
                    voice_and_tone messaging_guidelines prohibited_claims approved_ctas].freeze
  BRIEF_FIELDS = %w[name objective target_audience offer key_message desired_action channels brief].freeze

  def initialize(campaign)
    @campaign = campaign
  end

  def blocks(content_item: nil, variant: nil, instruction: nil, include_strategy: false)
    parts = []
    parts << block('brand_profile', brand_profile) if brand_profile
    parts << block('campaign_brief', brief)
    parts << block('campaign_strategy', @campaign.strategy) if include_strategy && @campaign.strategy.present?
    parts << block('content_item', content_item.slice('title', 'content_type')) if content_item
    parts << block('current_variant', variant.slice('platform', 'body', 'call_to_action', 'hashtags')) if variant
    parts << block('user_instruction', { 'instruction' => instruction }) if instruction.present?
    parts.join("\n\n")
  end

  private

  def brand_profile
    return @brand_profile if defined?(@brand_profile)

    profile = @campaign.account.glint_reach_brand_profile
    @brand_profile = profile && compact(profile.attributes.slice(*BRAND_FIELDS))
  end

  def brief
    data = compact(@campaign.attributes.slice(*BRIEF_FIELDS))
    data['notes'] = data.delete('brief') if data.key?('brief')
    data['starts_on'] = @campaign.starts_at.to_date.iso8601 if @campaign.starts_at
    data['ends_on'] = @campaign.ends_at.to_date.iso8601 if @campaign.ends_at
    data
  end

  def compact(hash)
    hash.reject { |_key, value| value.blank? }
  end

  def block(tag, data)
    "<#{tag}>\n#{JSON.generate(sanitize(data))}\n</#{tag}>"
  end

  def sanitize(value)
    case value
    when Hash then value.transform_values { |inner| sanitize(inner) }
    when Array then value.map { |inner| sanitize(inner) }
    when String then value.gsub(TAG_PATTERN, '')
    else value
    end
  end
end
