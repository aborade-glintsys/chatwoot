class GlintReach::BrandProfile < ApplicationRecord
  TEXT_LIMIT = 5_000
  MAX_LANGUAGES = 10
  MAX_CTAS = 20
  CTA_LENGTH = 100
  LANGUAGE_CODE = /\A[a-z]{2,3}(-[A-Za-z]{2,4})?\z/
  TEXT_FIELDS = %i[description products_services target_audience geographic_market
                   voice_and_tone messaging_guidelines prohibited_claims].freeze

  # All fields are untrusted user input. They are stored as plain text, rendered only with
  # text interpolation, and must be treated as data (never instructions) by future AI services.
  # The website URL is validated but never fetched by the server.

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :name, presence: true, length: { maximum: 255 }
  validates(*TEXT_FIELDS, length: { maximum: TEXT_LIMIT })
  validates :website_url, length: { maximum: 2048 }
  validate :website_url_format
  validate :preferred_languages_format
  validate :approved_ctas_format

  before_validation :normalize_lists
  before_validation { self.website_url = website_url.to_s.strip.presence }

  private

  def normalize_lists
    self.preferred_languages = Array(preferred_languages).map { |code| code.to_s.strip }.compact_blank.uniq
    self.approved_ctas = Array(approved_ctas).map { |cta| cta.to_s.squish }.compact_blank.uniq
  end

  def website_url_format
    return if website_url.blank?

    uri = URI.parse(website_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.blank?

    errors.add(:website_url, :invalid)
  rescue URI::InvalidURIError
    errors.add(:website_url, :invalid)
  end

  def preferred_languages_format
    errors.add(:preferred_languages, :too_many_items, count: MAX_LANGUAGES) if preferred_languages.size > MAX_LANGUAGES
    errors.add(:preferred_languages, :invalid) unless preferred_languages.all? { |code| code.match?(LANGUAGE_CODE) }
  end

  def approved_ctas_format
    errors.add(:approved_ctas, :too_many_items, count: MAX_CTAS) if approved_ctas.size > MAX_CTAS
    errors.add(:approved_ctas, :cta_too_long, count: CTA_LENGTH) if approved_ctas.any? { |cta| cta.length > CTA_LENGTH }
  end
end

GlintReach::BrandProfile.include_mod_with('Audit::GlintReach::BrandProfile')
