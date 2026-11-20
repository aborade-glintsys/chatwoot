# Daily maintenance job: marks expired social connections, verifies active tokens against their
# provider (marking 401s as revoked), and purges expired OAuth states.
class GlintReach::VerifySocialAccountsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    GlintReach::OauthState.expired_records.delete_all
    return unless Chatwoot.encryption_configured?

    GlintReach::SocialAccount.connected.find_each do |social_account|
      verify(social_account)
    end
  end

  private

  def verify(social_account)
    if social_account.token_expired?
      social_account.mark_status!(:expired, code: 'expired', message: I18n.t('errors.glint_reach.social.expired'))
      return
    end

    social_account.provider_client.fetch_identity(access_token: social_account.access_token)
    social_account.update!(last_verified_at: Time.current)
  rescue GlintReach::Social::Error::Revoked
    social_account.update!(
      access_token: nil, refresh_token: nil, status: :revoked,
      last_error_code: 'revoked', last_error_message: I18n.t('errors.glint_reach.social.revoked'),
      last_verified_at: Time.current
    )
  rescue GlintReach::Social::Error::ProviderUnavailable => e
    Rails.logger.warn("[GlintReach] Social account #{social_account.id} verification skipped: #{e.class}")
  end
end
