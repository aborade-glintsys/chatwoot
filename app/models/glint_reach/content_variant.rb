class GlintReach::ContentVariant < ApplicationRecord
  include GlintReach::Lifecycle

  TRANSITIONS = {
    'draft' => %w[ready],
    'ready' => %w[draft]
  }.freeze
  MAX_HASHTAGS = 30

  belongs_to :account
  belongs_to :content_item, class_name: 'GlintReach::ContentItem'

  # Common fields only. Platform-specific attributes, when a real requirement appears, go into a
  # single validated jsonb column (see docs/glintreach/architecture.md).
  enum :platform, { facebook: 0, instagram: 1, linkedin: 2, x: 3, tiktok: 4 }, validate: true
  enum :status, { draft: 0, ready: 1 }, validate: true

  validates :platform, uniqueness: { scope: :content_item_id }
  validates :body, length: { maximum: 10_000 }
  validates :call_to_action, length: { maximum: 255 }
  validate :hashtags_format

  before_validation { self.account_id = content_item&.account_id }
  before_validation :normalize_hashtags

  private

  def normalize_hashtags
    self.hashtags = Array(hashtags).map { |tag| tag.to_s.strip.delete_prefix('#') }.compact_blank.uniq
  end

  def hashtags_format
    errors.add(:hashtags, :too_long, count: MAX_HASHTAGS) if hashtags.size > MAX_HASHTAGS
    errors.add(:hashtags, :invalid) unless hashtags.all? { |tag| tag.match?(/\A[[:alnum:]_]{1,100}\z/) }
  end
end
