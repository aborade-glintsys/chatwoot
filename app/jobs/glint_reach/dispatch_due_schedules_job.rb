# Runs every minute from sidekiq-cron (config/schedule.yml). State lives in Postgres, so it does not
# depend on a browser and survives restarts. Due schedules are claimed with FOR UPDATE SKIP LOCKED,
# so concurrent runs never claim the same row; each claimed row gets one PublishScheduledJob.
class GlintReach::DispatchDueSchedulesJob < ApplicationJob
  queue_as :scheduled_jobs

  BATCH_SIZE = 100
  STALE_AFTER = 15.minutes
  MAX_ATTEMPTS = 3

  def perform
    recover_stale
    loop do
      ids = claim_batch
      ids.each { |id| GlintReach::PublishScheduledJob.perform_later(id) }
      break if ids.size < BATCH_SIZE
    end
  end

  private

  def claim_batch
    GlintReach::Schedule.transaction do
      ids = GlintReach::Schedule.due.order(:scheduled_at, :id).limit(BATCH_SIZE).lock('FOR UPDATE SKIP LOCKED').pluck(:id)
      GlintReach::Schedule.where(id: ids).update_all( # rubocop:disable Rails/SkipsModelValidations
        ['status = ?, dispatch_started_at = ?, attempts = attempts + 1, updated_at = ?',
         GlintReach::Schedule.statuses[:dispatching], Time.current, Time.current]
      )
      ids
    end
  end

  # A worker that died mid-dispatch leaves a row in `dispatching`; retry it a bounded number of times.
  def recover_stale
    GlintReach::Schedule.dispatching.where(dispatch_started_at: ...STALE_AFTER.ago).find_each do |schedule|
      GlintReach::PublishScheduledJob.new.recover_stale(schedule.id, max_attempts: MAX_ATTEMPTS)
    end
  end
end
