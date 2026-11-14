# Append-only review decision on a content variant. `content_digest` records exactly what was
# reviewed, so publishing can refuse content that changed after approval.
class GlintReach::Approval < ApplicationRecord
  MAX_FEEDBACK = 2_000

  belongs_to :account
  belongs_to :content_variant, class_name: 'GlintReach::ContentVariant'
  belongs_to :reviewer, class_name: 'User'

  enum :decision, { approved: 0, changes_requested: 1 }, validate: true

  validates :content_digest, presence: true
  validates :feedback, length: { maximum: MAX_FEEDBACK }
  validate :feedback_required_for_changes

  before_validation { self.account_id = content_variant&.account_id }
  before_validation { self.feedback = feedback.to_s.strip.presence }

  # Decisions are history; they are never edited.
  def readonly?
    persisted?
  end

  private

  def feedback_required_for_changes
    errors.add(:feedback, :blank) if changes_requested? && feedback.blank?
  end
end

GlintReach::Approval.include_mod_with('Audit::GlintReach::Approval')
