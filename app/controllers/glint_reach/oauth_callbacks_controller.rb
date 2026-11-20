# Top-level OAuth callback handler. Validates server-side single-use state and the HttpOnly browser
# cookie nonce before touching any account, then redirects back to the dashboard with a result code.
class GlintReach::OauthCallbacksController < ApplicationController
  def show
    nonce = cookies[GlintReach::Social::OauthFlow::COOKIE_NAME]
    cookies.delete(GlintReach::Social::OauthFlow::COOKIE_NAME, path: '/glint_reach/oauth')

    completion = GlintReach::Social::OauthFlow.complete(
      provider_key: params[:provider],
      state: params[:state],
      code: params[:code],
      error: params[:error],
      raw_nonce: nonce
    )
    redirect_to destination_for(completion), allow_other_host: true
  end

  private

  def destination_for(completion)
    origin = ENV.fetch('FRONTEND_URL', 'http://localhost:3000').to_s.strip.chomp('/')
    return "#{origin}/" if completion.account_id.blank?

    query = { oauth: completion.outcome, code: completion.error_code }.compact.to_query
    "#{origin}/app/accounts/#{completion.account_id}/glint-reach/social-accounts?#{query}"
  end
end
