# Review and scheduling actions on a content variant. Every action delegates to GlintReach::Workflow,
# which enforces transitions, roles and locking; nothing is inferred from the client.
class Api::V1::Accounts::GlintReach::VariantWorkflowsController < Api::V1::Accounts::GlintReach::BaseController
  before_action :fetch_variant

  def submit = run(&:submit!)
  def withdraw = run(&:withdraw!)
  def reopen = run(&:reopen!)
  def cancel_schedule = run(&:cancel_schedule!)

  def review
    run { |workflow| workflow.review!(decision: params.require(:decision), feedback: params[:feedback]) }
  end

  def schedule
    run do |workflow|
      workflow.schedule!(date: params.require(:date), time: params.require(:time), timezone: params.require(:timezone))
    end
  end

  def approvals
    @approvals = @variant.approvals.includes(:reviewer).reverse
  end

  private

  def fetch_variant
    @campaign = campaigns.find(params[:campaign_id])
    @content_item = @campaign.content_items.find(params[:content_item_id])
    @variant = @content_item.variants.find(params[:id])
  end

  def run
    yield GlintReach::Workflow.new(variant: @variant, user: Current.user, lock_version: params[:lock_version])
    @variant.reload
    render 'api/v1/accounts/glint_reach/content_variants/show'
  end
end
