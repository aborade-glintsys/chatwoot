# Account-scoped social account connections. Tokens are never rendered or accepted from the client.
class Api::V1::Accounts::GlintReach::SocialAccountsController < Api::V1::Accounts::GlintReach::BaseController
  def index
    @social_accounts = Current.account.glint_reach_social_accounts.includes(:connected_by).recent
  end

  # Named start_oauth so it does not shadow Pundit::Authorization#authorize.
  def start_oauth
    result = GlintReach::Social::OauthFlow.start(
      account: Current.account,
      user: Current.user,
      provider_key: params.require(:provider)
    )
    cookies[GlintReach::Social::OauthFlow::COOKIE_NAME] = {
      value: result[:nonce],
      httponly: true,
      secure: request.ssl?,
      same_site: :lax,
      path: '/glint_reach/oauth',
      expires: GlintReach::OauthState::TTL.from_now
    }
    render json: { url: result[:url] }
  rescue GlintReach::Social::Error => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_entity
  end

  def destroy
    @social_account = Current.account.glint_reach_social_accounts.find(params[:id])
    GlintReach::Social::OauthFlow.disconnect(social_account: @social_account)
    render :show
  end
end
