# LinkedIn OAuth 2.0 + OpenID Connect adapter (personal member profiles via Share on LinkedIn).
# Uses fixed LinkedIn hosts only; credentials come from InstallationConfig (never committed).
class GlintReach::Social::Providers::Linkedin < GlintReach::Social::Providers::Base
  OAUTH_HOST = 'www.linkedin.com'.freeze
  API_HOST = 'api.linkedin.com'.freeze
  AUTHORIZE_PATH = '/oauth/v2/authorization'.freeze
  TOKEN_PATH = '/oauth/v2/accessToken'.freeze
  REVOKE_PATH = '/oauth/v2/revoke'.freeze
  USERINFO_PATH = '/v2/userinfo'.freeze
  OIDC_ISSUER = 'https://www.linkedin.com/oauth'.freeze
  CLOCK_SKEW_SECONDS = 60

  REQUIRED_SCOPES = %w[openid profile w_member_social].freeze
  OPTIONAL_SCOPES = %w[email].freeze

  MEMBER_CAPABILITIES = GlintReach::Social::Capabilities.new(
    post_types: %w[text image],
    max_text_length: 3_000,
    max_images: 1,
    image_mime_types: %w[image/jpeg image/png image/gif],
    supports_video: false,
    supports_scheduling_natively: false,
    supports_refresh: false,
    token_lifetime_days: 60
  ).freeze

  def key = 'linkedin'
  def display_name = 'LinkedIn'
  def required_scopes = REQUIRED_SCOPES
  def optional_scopes = OPTIONAL_SCOPES

  def approval_notes
    'Self-serve products required in LinkedIn Developer Portal: "Sign In with LinkedIn using OpenID Connect" ' \
      'and "Share on LinkedIn". Personal member profiles only (no Company Pages); tokens expire after ~60 days.'
  end

  def configured?
    client_id.present? && client_secret.present?
  end

  def capabilities(account_type: 'member')
    raise ArgumentError, "Unsupported LinkedIn account type: #{account_type}" unless account_type.to_s == 'member'

    MEMBER_CAPABILITIES
  end

  def authorize_url(state:, code_challenge:, redirect_uri:)
    ensure_configured!
    query = URI.encode_www_form(
      response_type: 'code',
      client_id: client_id,
      redirect_uri: redirect_uri,
      state: state,
      scope: requested_scopes.join(' '),
      code_challenge: code_challenge,
      code_challenge_method: 'S256'
    )
    "https://#{OAUTH_HOST}#{AUTHORIZE_PATH}?#{query}"
  end

  def exchange_code(code:, code_verifier:, redirect_uri:)
    ensure_configured!
    response = post_form(
      TOKEN_PATH,
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: redirect_uri,
      client_id: client_id,
      client_secret: client_secret,
      code_verifier: code_verifier
    )
    build_token_set(response)
  end

  def fetch_identity(access_token:)
    response = get_userinfo(access_token)
    data = parse_json(response.body)
    sub = data['sub'].to_s.strip
    raise GlintReach::Social::Error::TokenExchangeFailed, 'Missing member identifier' if sub.blank?

    name = data['name'].presence || [data['given_name'], data['family_name']].compact_blank.join(' ').presence || sub
    GlintReach::Social::Identity.new(
      provider_account_id: sub,
      provider_account_type: 'member',
      display_name: name.truncate(255),
      profile_url: nil,
      avatar_url: valid_avatar_url(data['picture'])
    )
  end

  def revoke(access_token)
    return if access_token.blank? || !configured?

    http_connection(OAUTH_HOST).post(REVOKE_PATH) do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form(client_id: client_id, client_secret: client_secret, token: access_token)
    end
  rescue Faraday::Error => e
    Rails.logger.warn("[GlintReach] LinkedIn token revoke failed: #{e.class}")
  end

  private

  def client_id
    InstallationConfig.find_by(name: 'GLINT_REACH_LINKEDIN_CLIENT_ID')&.value.presence
  end

  def client_secret
    InstallationConfig.find_by(name: 'GLINT_REACH_LINKEDIN_CLIENT_SECRET')&.value.presence
  end

  def ensure_configured!
    raise GlintReach::Social::Error::NotConfigured, I18n.t('errors.glint_reach.social.not_configured') unless configured?
  end

  def post_form(path, params)
    response = http_connection(OAUTH_HOST).post(path) do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form(params)
    end
    handle_token_response(response)
  rescue Faraday::Error => e
    raise GlintReach::Social::Error::ProviderUnavailable, e.message
  end

  def handle_token_response(response)
    return parse_json(response.body) if response.status.between?(200, 299)
    raise GlintReach::Social::Error::ProviderUnavailable, "HTTP #{response.status}" if response.status >= 500

    raise GlintReach::Social::Error::TokenExchangeFailed, "HTTP #{response.status}"
  end

  def build_token_set(data)
    access_token = data['access_token'].to_s
    raise GlintReach::Social::Error::TokenExchangeFailed, 'Missing access_token' if access_token.blank?

    verify_id_token!(data['id_token']) if data['id_token'].present?
    GlintReach::Social::TokenSet.new(
      access_token: access_token, refresh_token: data['refresh_token'].presence,
      expires_at: expiry_from(data['expires_in']), refresh_expires_at: expiry_from(data['refresh_token_expires_in']),
      scopes: data['scope'].to_s.split(/[\s,]+/).compact_blank.uniq, id_token: data['id_token'].presence
    )
  end

  def expiry_from(seconds)
    seconds.to_i.positive? ? Time.current + seconds.to_i.seconds : nil
  end

  # Verifies OIDC claims on the ID token returned directly over TLS from LinkedIn's token endpoint.
  def verify_id_token!(id_token)
    claims = JWT.decode(id_token, nil, false).first
    aud = Array(claims['aud'])
    exp = claims['exp'].to_i
    valid = claims['iss'] == OIDC_ISSUER && aud.include?(client_id) && exp > Time.current.to_i - CLOCK_SKEW_SECONDS
    raise GlintReach::Social::Error::TokenExchangeFailed, 'Invalid ID token claims' unless valid
  rescue JWT::DecodeError
    raise GlintReach::Social::Error::TokenExchangeFailed, 'Malformed ID token'
  end

  def get_userinfo(access_token)
    response = http_connection(API_HOST).get(USERINFO_PATH) do |req|
      req.headers['Authorization'] = "Bearer #{access_token}"
    end
    return response if response.status.between?(200, 299)
    raise GlintReach::Social::Error::Revoked, 'Provider rejected access token' if response.status == 401
    raise GlintReach::Social::Error::ProviderUnavailable, "HTTP #{response.status}" if response.status >= 500

    raise GlintReach::Social::Error::TokenExchangeFailed, "HTTP #{response.status}"
  rescue Faraday::Error => e
    raise GlintReach::Social::Error::ProviderUnavailable, e.message
  end

  def valid_avatar_url(url)
    uri = URI.parse(url.to_s)
    uri.is_a?(URI::HTTPS) ? url.to_s.truncate(2048) : nil
  rescue URI::InvalidURIError
    nil
  end
end
