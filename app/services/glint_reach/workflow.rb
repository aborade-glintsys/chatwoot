# The only place content-variant workflow statuses change. Every action runs in a transaction with
# the variant row locked (and its live schedule locked second), checks the caller's optimistic
# `lock_version`, the allowed-transition table and the role rules below.
#
# Roles (GlintReach is limited to account administrators by GlintReachPolicy):
#   submit / withdraw / reopen / schedule / reschedule / cancel: any administrator
#   approve / request changes: an administrator who did not submit the variant (no self-approval)
class GlintReach::Workflow
  class Error < StandardError; end
  class Forbidden < Error; end
  class Conflict < Error; end

  attr_reader :variant, :user

  def initialize(variant:, user:, lock_version: nil)
    @variant = variant
    @user = user
    @lock_version = lock_version.presence&.to_i
  end

  def submit!
    perform(to: 'in_review') do
      fail_with!(Conflict, :body_required) if variant.body.blank?
      variant.update!(status: :in_review, submitted_by: user, submitted_at: Time.current)
    end
  end

  def withdraw!
    perform(to: 'draft', from: %w[in_review]) { variant.update!(status: :draft) }
  end

  def review!(decision:, feedback: nil)
    decision = decision.to_s
    fail_with!(Conflict, :invalid_decision) unless GlintReach::Approval.decisions.key?(decision)

    perform(to: decision) do
      fail_with!(Forbidden, :self_review) if variant.submitted_by_id == user.id
      GlintReach::Approval.create!(content_variant: variant, reviewer: user, decision: decision, feedback: feedback,
                                   content_digest: variant.content_digest)
      variant.update!(status: decision)
    end
  end

  def reopen!
    perform(to: 'draft', from: %w[approved failed]) do
      variant.update!(status: :draft, submitted_by: nil, submitted_at: nil)
    end
  end

  def schedule!(date:, time:, timezone:)
    perform(to: 'scheduled', allow_same: true) do
      approval = current_approval!
      at = GlintReach::Workflow::ScheduleTime.parse(date: date, time: time, timezone: timezone, campaign: campaign)
      variant.scheduled? ? reschedule!(at, timezone) : create_schedule!(at, timezone, approval)
    end
  rescue GlintReach::Workflow::ScheduleTime::Invalid => e
    raise Conflict, e.message
  end

  def cancel_schedule!
    perform(to: 'approved', from: %w[scheduled], allow_locked_campaign: true) do
      schedule = live_schedule!
      fail_with!(Conflict, :dispatch_started) unless schedule.pending?
      schedule.update!(status: :cancelled, finished_at: Time.current)
      variant.update!(status: :approved)
    end
  end

  # Flags for the UI. The server re-checks everything when an action is called.
  PERMISSION_STATUSES = {
    submit: %w[draft changes_requested],
    withdraw: %w[in_review],
    review: %w[in_review],
    reopen: %w[approved failed],
    schedule: %w[approved failed scheduled]
  }.freeze

  def permissions
    open_campaign = !campaign.locked?
    flags = PERMISSION_STATUSES.transform_values { |statuses| open_campaign && statuses.include?(variant.status) }
    flags[:review] &&= variant.submitted_by_id != user.id
    { edit: open_campaign && variant.editable?, **flags, cancel_schedule: variant.scheduled? }
  end

  private

  def campaign = variant.content_item.campaign

  def perform(to:, from: nil, allow_same: false, allow_locked_campaign: false)
    ActiveRecord::Base.transaction do
      variant.lock!
      check_lock_version!
      fail_with!(Conflict, :campaign_locked) if !allow_locked_campaign && campaign.locked?
      check_transition!(to, from, allow_same)
      yield
    end
    variant
  rescue ActiveRecord::RecordNotUnique
    fail_with!(Conflict, :already_scheduled)
  end

  def check_lock_version!
    return if @lock_version.nil? || @lock_version == variant.lock_version

    fail_with!(Conflict, :stale)
  end

  def check_transition!(to, from, allow_same)
    return if allow_same && variant.status == to
    return if variant.can_transition_to?(to) && (from.nil? || from.include?(variant.status))

    fail_with!(Conflict, :invalid_transition, from: variant.status, to: to)
  end

  # The newest decision must be an approval of exactly the current content.
  def current_approval!
    approval = variant.approvals.last
    fail_with!(Conflict, :approval_missing) unless approval&.approved?
    fail_with!(Conflict, :approval_stale) unless approval.content_digest == variant.content_digest
    approval
  end

  def create_schedule!(at, timezone, approval)
    variant.schedules.create!(scheduled_at: at, timezone: timezone, approval: approval, scheduled_by: user)
    variant.update!(status: :scheduled)
  end

  def reschedule!(at, timezone)
    schedule = live_schedule!
    fail_with!(Conflict, :dispatch_started) unless schedule.pending?
    schedule.update!(scheduled_at: at, timezone: timezone, scheduled_by: user)
    variant.update!(updated_at: Time.current) # bumps lock_version so other open editors see the change
  end

  def live_schedule!
    variant.schedules.live.lock.order(:id).last || fail_with!(Conflict, :schedule_missing)
  end

  def fail_with!(klass, key, **)
    raise klass, I18n.t("errors.glint_reach.workflow.#{key}", **)
  end
end
