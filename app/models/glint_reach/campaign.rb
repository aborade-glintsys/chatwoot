class GlintReach::Campaign < ApplicationRecord
  include GlintReach::Lifecycle

  TRANSITIONS = {
    'draft' => %w[active archived],
    'active' => %w[paused completed],
    'paused' => %w[active completed archived],
    'completed' => %w[archived]
  }.freeze
  LOCKED_STATUSES = %w[completed archived].freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User'
  has_many :content_items, -> { order(:id) }, class_name: 'GlintReach::ContentItem', dependent: :destroy, inverse_of: :campaign

  enum :objective, { awareness: 0, engagement: 1, traffic: 2, leads: 3, sales: 4 }, validate: true
  enum :status, { draft: 0, active: 1, paused: 2, completed: 3, archived: 4 }, validate: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :brief, :target_audience, length: { maximum: 10_000 }
  validate :ends_after_start
  validate :creator_belongs_to_account, on: :create

  scope :not_archived, -> { where.not(status: :archived) }
  scope :search_by_name, ->(term) { where('glint_reach_campaigns.name ILIKE ?', "%#{sanitize_sql_like(term)}%") }

  def locked?
    LOCKED_STATUSES.include?(status_was)
  end

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, :must_be_after_start)
  end

  def creator_belongs_to_account
    return if created_by.blank? || account.blank?
    return if account.account_users.exists?(user_id: created_by_id)

    errors.add(:created_by, :not_account_member)
  end
end

GlintReach::Campaign.include_mod_with('Audit::GlintReach::Campaign')
