# Handles one claimed schedule. Idempotent: it acts only while the schedule is `dispatching` and the
# variant is `scheduled`, under row locks (variant first, then schedule, the same order as cancel).
# Everything is revalidated before dispatch. No publishers exist yet, so the final eligibility
# check records `publisher_unavailable`; no external request is made in this phase.
class GlintReach::PublishScheduledJob < ApplicationJob
  queue_as :medium

  def perform(schedule_id)
    schedule = GlintReach::Schedule.find_by(id: schedule_id)
    return if schedule.nil?

    with_locks(schedule) do |variant, locked|
      next unless locked.dispatching? && variant.scheduled?

      variant.update!(status: :publishing)
      # The publish call itself arrives with the first publisher. Until then an eligible variant
      # cannot exist (the registry is empty), and nothing is ever reported as published.
      fail!(variant, locked, ineligibility(variant, locked) || 'publisher_unavailable')
    end
  end

  def recover_stale(schedule_id, max_attempts:)
    schedule = GlintReach::Schedule.find_by(id: schedule_id)
    return if schedule.nil?

    with_locks(schedule) do |variant, locked|
      next unless locked.dispatching? && locked.dispatch_started_at < GlintReach::DispatchDueSchedulesJob::STALE_AFTER.ago

      if locked.attempts < max_attempts
        locked.update!(status: :pending, dispatch_started_at: nil)
        variant.update!(status: :scheduled) if variant.publishing?
      else
        fail!(variant, locked, 'dispatch_timeout')
      end
    end
  end

  private

  def with_locks(schedule)
    ActiveRecord::Base.transaction do
      variant = GlintReach::ContentVariant.lock.find(schedule.content_variant_id)
      locked = GlintReach::Schedule.lock.find(schedule.id)
      yield variant, locked
    end
  end

  def ineligibility(variant, schedule)
    campaign = variant.content_item.campaign
    return 'glint_reach_disabled' unless variant.account.feature_enabled?(:glint_reach)
    return 'campaign_not_active' unless campaign.active?
    return 'approval_invalid' unless approval_valid?(variant, schedule)
    return 'publisher_unavailable' unless GlintReach::Publishers.available?(variant.platform, variant.account)

    nil
  end

  def approval_valid?(variant, schedule)
    latest = variant.approvals.last
    latest&.approved? && latest.id == schedule.approval_id && latest.content_digest == variant.content_digest
  end

  def fail!(variant, schedule, code)
    schedule.mark_failed!(code: code, message: I18n.t("errors.glint_reach.dispatch.#{code}"))
    variant.update!(status: :failed) if variant.publishing? || variant.scheduled?
  end
end
