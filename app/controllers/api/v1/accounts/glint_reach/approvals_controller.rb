# Approval queue: variants waiting for review in this account, oldest submission first.
class Api::V1::Accounts::GlintReach::ApprovalsController < Api::V1::Accounts::GlintReach::BaseController
  RESULTS_PER_PAGE = 25

  def index
    @current_page = [params[:page].to_i, 1].max
    scope = GlintReach::ContentVariant.where(account_id: Current.account.id).in_review
    @count = scope.count
    @variants = scope.includes(:submitted_by, :latest_schedule, { latest_approval: :reviewer },
                               assets: { file_attachment: :blob }, content_item: :campaign)
                     .order(:submitted_at, :id).page(@current_page).per(RESULTS_PER_PAGE)
  end
end
