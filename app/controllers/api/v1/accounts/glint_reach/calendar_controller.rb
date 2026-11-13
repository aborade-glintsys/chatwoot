# Calendar and list feed: schedules (excluding cancelled) whose time falls between the start of
# `from` and the end of `to`, both interpreted in `timezone`. Account scoped.
class Api::V1::Accounts::GlintReach::CalendarController < Api::V1::Accounts::GlintReach::BaseController
  MAX_DAYS = 62

  def index
    zone = parse_zone
    range = parse_range(zone)
    return render_invalid_range if zone.nil? || range.nil?

    @schedules = filtered_schedules(range).includes(content_variant: { content_item: :campaign }).order(:scheduled_at, :id)
  end

  private

  def parse_zone
    name = params[:timezone].presence || 'UTC'
    TZInfo::Timezone.get(name)
    ActiveSupport::TimeZone[name]
  rescue TZInfo::InvalidTimezoneIdentifier
    nil
  end

  def parse_range(zone)
    return if zone.nil?

    from = Date.iso8601(params.require(:from))
    to = Date.iso8601(params.require(:to))
    return if to < from || (to - from).to_i >= MAX_DAYS

    zone.parse(from.iso8601).beginning_of_day..zone.parse(to.iso8601).end_of_day
  rescue Date::Error, ActionController::ParameterMissing
    nil
  end

  def filtered_schedules(range)
    scope = GlintReach::Schedule.where(account_id: Current.account.id).where.not(status: :cancelled).where(scheduled_at: range)
    statuses = Array(params[:status]).map(&:to_s) & GlintReach::Schedule.statuses.keys
    scope = scope.where(status: statuses) if statuses.any?
    if params[:campaign_id].present?
      scope = scope.joins(content_variant: :content_item).where(glint_reach_content_items: { campaign_id: params[:campaign_id] })
    end
    scope
  end

  def render_invalid_range
    render json: { error: I18n.t('errors.glint_reach.calendar.invalid_range') }, status: :unprocessable_entity
  end
end
