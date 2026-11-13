class GlintReach::Generation < ApplicationRecord
  ACTIVE_STATUSES = %w[queued generating].freeze
  # Kinds that act on one content variant / content item.
  VARIANT_KINDS = %w[rewrite suggestions].freeze
  ITEM_KINDS = %w[variants].freeze
  MAX_INSTRUCTION_LENGTH = 500
  MAX_PLAN_ITEMS = 10
  MAX_BODY_LENGTH = 3_000
  HASHTAG_PATTERN = '^[A-Za-z0-9_]{1,100}$'.freeze

  belongs_to :account
  belongs_to :campaign, class_name: 'GlintReach::Campaign'
  belongs_to :content_item, class_name: 'GlintReach::ContentItem', optional: true
  belongs_to :content_variant, class_name: 'GlintReach::ContentVariant', optional: true
  belongs_to :requested_by, class_name: 'User'

  enum :kind, { strategy: 0, content_plan: 1, content_item: 2, variants: 3, rewrite: 4, suggestions: 5 }, validate: true
  enum :status, { queued: 0, generating: 1, completed: 2, failed: 3 }, validate: true

  validates :error_message, length: { maximum: 500 }
  validate :target_matches_kind
  validate :target_belongs_to_campaign

  before_validation { self.account_id = campaign&.account_id }

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :recent, -> { order(created_at: :desc) }

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def target_scope
    { campaign_id: campaign_id, kind: kind, content_item_id: content_item_id, content_variant_id: content_variant_id }
  end

  def mark_generating!
    update!(status: :generating, started_at: Time.current, error_code: nil, error_message: nil)
  end

  def mark_completed!(result:, response:)
    update!(
      status: :completed, result: result, completed_at: Time.current,
      provider: response.provider, model: response.model,
      input_tokens: response.usage[:input_tokens], output_tokens: response.usage[:output_tokens],
      credit_multiplier: response.usage[:credit_multiplier]
    )
  end

  def mark_failed!(code:, message:)
    update!(status: :failed, error_code: code, error_message: message.to_s.truncate(500), completed_at: Time.current)
  end

  private

  def target_matches_kind
    errors.add(:content_variant, :blank) if VARIANT_KINDS.include?(kind) && content_variant_id.blank?
    errors.add(:content_item, :blank) if ITEM_KINDS.include?(kind) && content_item_id.blank?
  end

  def target_belongs_to_campaign
    errors.add(:content_item, :invalid) if content_item && content_item.campaign_id != campaign_id
    errors.add(:content_variant, :invalid) if content_variant && content_variant.content_item.campaign_id != campaign_id
  end
end
