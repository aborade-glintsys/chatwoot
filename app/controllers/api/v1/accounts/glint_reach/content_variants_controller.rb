class Api::V1::Accounts::GlintReach::ContentVariantsController < Api::V1::Accounts::GlintReach::BaseController
  before_action :fetch_parents
  before_action :ensure_campaign_editable
  before_action :fetch_variant, except: [:create]

  def create
    @variant = @content_item.variants.create!(variant_params)
    render :show
  end

  def update
    @variant.update!(variant_params)
    render :show
  end

  def destroy
    raise GlintReach::Workflow::Conflict, I18n.t('errors.glint_reach.workflow.dispatch_started') if @variant.scheduled? || @variant.publishing?

    @variant.destroy!
    head :ok
  end

  # Phase 02 compatibility endpoint. Only moves that need no extra input are supported, and they go
  # through GlintReach::Workflow (roles, locks, approval records). Others return 409.
  def transition
    workflow = GlintReach::Workflow.new(variant: @variant, user: Current.user, lock_version: params[:lock_version])
    case [@variant.status, params.require(:status)]
    in [('draft' | 'changes_requested'), 'in_review'] then workflow.submit!
    in ['in_review', 'draft'] then workflow.withdraw!
    in [('approved' | 'failed'), 'draft'] then workflow.reopen!
    in [from, to]
      raise GlintReach::Workflow::Conflict, I18n.t('errors.glint_reach.workflow.invalid_transition', from: from, to: to)
    end
    render :show
  end

  private

  def fetch_parents
    @campaign = campaigns.find(params[:campaign_id])
    @content_item = @campaign.content_items.find(params[:content_item_id])
  end

  def fetch_variant
    @variant = @content_item.variants.find(params[:id])
  end

  def variant_params
    params.require(:variant).permit(:platform, :body, :call_to_action, hashtags: [])
  end
end
