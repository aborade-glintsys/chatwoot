# Converts a wall-clock date and time in an explicit IANA timezone to UTC, deterministically:
#   * local times skipped by a DST change ("spring forward") are rejected;
#   * local times that occur twice ("fall back") resolve to the FIRST occurrence;
#   * the result must be at least MIN_LEAD in the future and at most MAX_AHEAD away;
#   * when the campaign has dates, the result must fall inside them.
class GlintReach::Workflow::ScheduleTime
  class Invalid < StandardError; end

  MIN_LEAD = 5.minutes
  MAX_AHEAD = 1.year
  DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/
  TIME_FORMAT = /\A([01]\d|2[0-3]):([0-5]\d)\z/

  def self.parse(...) = new(...).parse

  def initialize(date:, time:, timezone:, campaign: nil, now: Time.current)
    @date = date.to_s.strip
    @time = time.to_s.strip
    @timezone = timezone.to_s.strip
    @campaign = campaign
    @now = now
  end

  def parse
    utc = to_utc
    check_window!(utc)
    utc
  end

  private

  def to_utc
    zone = tzinfo
    local = local_wall_time
    # Ambiguous local times: the period with the largest UTC offset gives the earliest instant,
    # i.e. the first time the wall clock shows that time.
    zone.local_to_utc(local) { |periods| periods.max_by(&:utc_offset) }.utc
  rescue TZInfo::PeriodNotFound
    invalid!(:nonexistent_time)
  end

  def tzinfo
    invalid!(:invalid_timezone) if @timezone.blank?
    TZInfo::Timezone.get(@timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    invalid!(:invalid_timezone)
  end

  def local_wall_time
    invalid!(:invalid_date) unless @date.match?(DATE_FORMAT)
    match = TIME_FORMAT.match(@time) || invalid!(:invalid_time)
    date = Date.iso8601(@date)
    Time.utc(date.year, date.month, date.day, match[1].to_i, match[2].to_i)
  rescue Date::Error
    invalid!(:invalid_date)
  end

  def check_window!(utc)
    invalid!(:too_soon, minutes: MIN_LEAD.in_minutes.to_i) if utc < @now + MIN_LEAD
    invalid!(:too_far) if utc > @now + MAX_AHEAD
    check_campaign_dates!(utc) if @campaign
  end

  def check_campaign_dates!(utc)
    invalid!(:before_campaign) if @campaign.starts_at && utc < @campaign.starts_at
    invalid!(:after_campaign) if @campaign.ends_at && utc > @campaign.ends_at
  end

  def invalid!(key, **)
    raise Invalid, I18n.t("errors.glint_reach.schedule_time.#{key}", **)
  end
end
