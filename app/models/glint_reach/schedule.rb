# A request to publish an approved variant at `scheduled_at` (UTC). `timezone` is the IANA zone the
# user chose and is kept for display. At most one pending/dispatching schedule per variant is
# enforced by a partial unique index. State changes happen in GlintReach::Workflow and the
# dispatch jobs, always under row locks (variant first, then schedule).
class GlintReach::Schedule < ApplicationRecord
  LIVE_STATUSES = %w[pending dispatching].freeze

  belongs_to :account
  belongs_to :content_variant, class_name: 'GlintReach::ContentVariant'
  belongs_to :approval, class_name: 'GlintReach::Approval'
  belongs_to :scheduled_by, class_name: 'User'

  enum :status, { pending: 0, dispatching: 1, dispatched: 2, cancelled: 3, failed: 4 }, validate: true

  validates :scheduled_at, :timezone, presence: true
  validates :error_message, length: { maximum: 500 }

  before_validation { self.account_id = content_variant&.account_id }

  scope :live, -> { where(status: LIVE_STATUSES) }
  scope :due, ->(now = Time.current) { pending.where(scheduled_at: ..now) }

  def mark_failed!(code:, message:)
    update!(status: :failed, error_code: code, error_message: message.to_s.truncate(500), finished_at: Time.current)
  end
end

GlintReach::Schedule.include_mod_with('Audit::GlintReach::Schedule')
