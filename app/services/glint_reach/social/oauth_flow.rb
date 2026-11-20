# Server-side OAuth orchestration: state issuance, callback verification, scope checks and disconnect.
# Redirect URIs are always derived from FRONTEND_URL; request host headers are never trusted.
class GlintReach::Social::OauthFlow
  COOKIE_NAME = 'glint_reach_oauth_nonce'.freeze
  DENIED_ERRORS = %w[access_denied user_cancelled_login user_cancelled_authorize].freeze

  Completion = Data.define(:account_id, :social_account, :outcome, :error_code)

  class << self
    def redirect_uri_for(provider_key)
      origin = validated_origin
      "#{origin}/glint_reach/oauth/#{provider_key}/callback"
    end

    def start(account:, user:, provider_key:)
      ensure_encryption!
      provider = GlintReach::Social::Providers.build(provider_key)
      raise GlintReach::Social::Error::NotConfigured, I18n.t('errors.glint_reach.social.not_configured') unless provider.configured?

      oauth_state, raw_state, raw_nonce = GlintReach::OauthState.issue!(account: account, user: user, provider: provider.key)
      url = provider.authorize_url(
        state: raw_state,
        code_challenge: oauth_state.code_challenge,
        redirect_uri: redirect_uri_for(provider.key)
      )
      { url: url, nonce: raw_nonce }
    end

    def complete(provider_key:, state:, code:, error:, raw_nonce:)
      oauth_state = consume_state!(state: state, provider_key: provider_key, raw_nonce: raw_nonce)
      ensure_still_authorized!(oauth_state)
      ensure_encryption!
      handle_provider_error!(error) if error.present?
      raise GlintReach::Social::Error::TokenExchangeFailed, 'Missing authorization code' if code.blank?

      provider = GlintReach::Social::Providers.build(provider_key)
      token_set = provider.exchange_code(code: code, code_verifier: oauth_state.code_verifier,
                                         redirect_uri: redirect_uri_for(provider.key))
      identity = provider.fetch_identity(access_token: token_set.access_token)
      account_record = upsert_account!(oauth_state: oauth_state, provider: provider, token_set: token_set, identity: identity)
      outcome = account_record.connected? ? 'connected' : 'missing_scopes'
      Completion.new(account_id: oauth_state.account_id, social_account: account_record, outcome: outcome,
                     error_code: account_record.last_error_code)
    rescue GlintReach::Social::Error => e
      Completion.new(account_id: oauth_state&.account_id, social_account: nil, outcome: 'error', error_code: e.code)
    end

    def disconnect(social_account:)
      social_account.provider_client.revoke(social_account.access_token) if social_account.access_token.present?
      social_account.update!(
        access_token: nil, refresh_token: nil, token_expires_at: nil, refresh_expires_at: nil,
        status: :revoked, last_error_code: 'disconnected',
        last_error_message: I18n.t('errors.glint_reach.social.disconnected'), last_verified_at: Time.current
      )
      social_account
    end

    private

    def ensure_encryption!
      return if Chatwoot.encryption_configured?

      raise GlintReach::Social::Error::EncryptionRequired, I18n.t('errors.glint_reach.social.encryption_required')
    end

    def validated_origin
      raw = ENV.fetch('FRONTEND_URL', 'http://localhost:3000').to_s.strip.chomp('/')
      uri = URI.parse(raw)
      valid = uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.blank? && uri.query.blank? && uri.fragment.blank?
      raise GlintReach::Social::Error::NotConfigured, I18n.t('errors.glint_reach.social.invalid_frontend_url') unless valid

      raw
    rescue URI::InvalidURIError
      raise GlintReach::Social::Error::NotConfigured, I18n.t('errors.glint_reach.social.invalid_frontend_url')
    end

    def consume_state!(state:, provider_key:, raw_nonce:)
      raise GlintReach::Social::Error::InvalidState, I18n.t('errors.glint_reach.social.invalid_state') if state.blank?

      ActiveRecord::Base.transaction do
        record = GlintReach::OauthState.lock.find_by(state_digest: GlintReach::OauthState.digest(state))
        unless record&.usable?(provider: provider_key, raw_nonce: raw_nonce)
          raise GlintReach::Social::Error::InvalidState, I18n.t('errors.glint_reach.social.invalid_state')
        end

        record.update!(consumed_at: Time.current)
        record
      end
    end

    def ensure_still_authorized!(oauth_state)
      account = oauth_state.account
      account_user = AccountUser.find_by(account_id: account.id, user_id: oauth_state.user_id)
      return if account.feature_enabled?(:glint_reach) && account_user&.administrator?

      raise GlintReach::Social::Error::InvalidState, I18n.t('errors.glint_reach.social.invalid_state')
    end

    def handle_provider_error!(error)
      raise GlintReach::Social::Error::AccessDenied, I18n.t('errors.glint_reach.social.access_denied') if DENIED_ERRORS.include?(error.to_s)

      raise GlintReach::Social::Error::TokenExchangeFailed, I18n.t('errors.glint_reach.social.token_exchange_failed')
    end

    def upsert_account!(oauth_state:, provider:, token_set:, identity:)
      record = GlintReach::SocialAccount.find_or_initialize_by(
        account_id: oauth_state.account_id, provider: provider.key, provider_account_id: identity.provider_account_id
      )
      attrs = account_attributes(oauth_state: oauth_state, token_set: token_set, identity: identity)
      record.update!(attrs.merge(scope_status_attributes(provider.missing_scopes(token_set.scopes))))
      record
    end

    def account_attributes(oauth_state:, token_set:, identity:)
      {
        connected_by_id: oauth_state.user_id, provider_account_type: identity.provider_account_type,
        display_name: identity.display_name, profile_url: identity.profile_url, avatar_url: identity.avatar_url,
        access_token: token_set.access_token, refresh_token: token_set.refresh_token,
        granted_scopes: token_set.scopes, token_expires_at: token_set.expires_at,
        refresh_expires_at: token_set.refresh_expires_at, last_verified_at: Time.current
      }
    end

    def scope_status_attributes(missing)
      return { status: :connected, last_error_code: nil, last_error_message: nil } if missing.empty?

      { status: :missing_scopes, last_error_code: 'missing_scopes',
        last_error_message: I18n.t('errors.glint_reach.social.missing_scopes', scopes: missing.join(', ')) }
    end
  end
end
