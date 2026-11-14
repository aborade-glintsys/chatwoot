class GlintReach::ContentVariant < ApplicationRecord
  # Allowed status moves. They are performed only by GlintReach::Workflow, which also checks
  # permissions, locks and approval records; the table here is the single source of truth.
  TRANSITIONS = {
    'draft' => %w[in_review],
    'in_review' => %w[approved changes_requested draft],
    'changes_requested' => %w[in_review],
    'approved' => %w[scheduled draft],
    'scheduled' => %w[approved publishing],
    'publishing' => %w[published failed],
    'failed' => %w[scheduled draft],
    'published' => []
  }.freeze
  # Content (text, hashtags, assets) can only change, by hand or by AI, in these states.
  EDITABLE_STATUSES = %w[draft changes_requested].freeze
  MAX_HASHTAGS = 30

  belongs_to :account
  belongs_to :content_item, class_name: 'GlintReach::ContentItem'
  # Set when the record was drafted by AI (Phase 04); nil for manual content.
  belongs_to :generation, class_name: 'GlintReach::Generation', optional: true
  has_many :variant_assets, -> { order(:position, :id) }, class_name: 'GlintReach::VariantAsset', dependent: :delete_all,
                                                          inverse_of: :content_variant
  has_many :assets, through: :variant_assets
  belongs_to :submitted_by, class_name: 'User', optional: true
  has_many :approvals, -> { order(:id) }, class_name: 'GlintReach::Approval', dependent: :delete_all, inverse_of: :content_variant
  has_one :latest_approval, -> { order(id: :desc) },
          class_name: 'GlintReach::Approval', inverse_of: :content_variant, dependent: nil
  has_many :schedules, class_name: 'GlintReach::Schedule', dependent: :delete_all, inverse_of: :content_variant
  has_one :latest_schedule, -> { where.not(status: :cancelled).order(id: :desc) },
          class_name: 'GlintReach::Schedule', inverse_of: :content_variant, dependent: nil

  # Common fields only. Platform-specific attributes, when a real requirement appears, go into a
  # single validated jsonb column (see docs/glintreach/architecture.md).
  enum :platform, { facebook: 0, instagram: 1, linkedin: 2, x: 3, tiktok: 4 }, validate: true
  enum :status, { draft: 0, in_review: 1, changes_requested: 2, approved: 3, scheduled: 4, publishing: 5, published: 6, failed: 7 },
       validate: true

  validates :platform, uniqueness: { scope: :content_item_id }
  validates :body, length: { maximum: 10_000 }
  validates :call_to_action, length: { maximum: 255 }
  validate :hashtags_format
  validate :content_frozen, on: :update

  before_validation { self.account_id = content_item&.account_id }
  before_validation :normalize_hashtags

  def editable?
    EDITABLE_STATUSES.include?(status_was || status)
  end

  def can_transition_to?(new_status)
    TRANSITIONS.fetch(status, []).include?(new_status.to_s)
  end

  # Fingerprint of everything a reviewer approves. Asset IDs are ordered as shown.
  def content_digest
    payload = [body.to_s, call_to_action.to_s, Array(hashtags), variant_assets.reload.map(&:asset_id)]
    Digest::SHA256.hexdigest(JSON.generate(payload))
  end

  private

  def content_frozen
    return if EDITABLE_STATUSES.include?(status_was)
    return unless will_save_change_to_body? || will_save_change_to_call_to_action? || will_save_change_to_hashtags? ||
                  will_save_change_to_platform?

    errors.add(:base, I18n.t('errors.glint_reach.workflow.content_locked'))
  end

  def normalize_hashtags
    self.hashtags = Array(hashtags).map { |tag| tag.to_s.strip.delete_prefix('#') }.compact_blank.uniq
  end

  def hashtags_format
    errors.add(:hashtags, :too_long, count: MAX_HASHTAGS) if hashtags.size > MAX_HASHTAGS
    errors.add(:hashtags, :invalid) unless hashtags.all? { |tag| tag.match?(/\A[[:alnum:]_]{1,100}\z/) }
  end
end
