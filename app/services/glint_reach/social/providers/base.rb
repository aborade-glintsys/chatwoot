# Contract every social provider adapter implements. Adding a platform means subclassing Base and
# registering it in GlintReach::Social::Providers::REGISTRY; OAuth flow and controllers stay unchanged.
class GlintReach::Social::Providers::Base
  HTTP_TIMEOUT = 15
  HTTP_OPEN_TIMEOUT = 5

  def key = raise(NotImplementedError)
  def display_name = raise(NotImplementedError)
  def required_scopes = raise(NotImplementedError)
  def optional_scopes = []
  def configured? = raise(NotImplementedError)
  def approval_notes = ''
  def authorize_url(state:, code_challenge:, redirect_uri:) = raise(NotImplementedError)
  def exchange_code(code:, code_verifier:, redirect_uri:) = raise(NotImplementedError)
  def fetch_identity(access_token:) = raise(NotImplementedError)
  def capabilities(account_type: 'member') = raise(NotImplementedError)

  def refresh(_refresh_token)
    raise GlintReach::Social::Error::RefreshUnsupported, I18n.t('errors.glint_reach.social.refresh_unsupported')
  end

  def revoke(_access_token)
    nil
  end

  def requested_scopes
    (required_scopes + optional_scopes).uniq
  end

  def missing_scopes(granted_scopes)
    required_scopes - Array(granted_scopes).map(&:to_s)
  end

  def metadata
    {
      key: key,
      display_name: display_name,
      configured: configured?,
      encryption_configured: Chatwoot.encryption_configured?,
      connectable: configured? && Chatwoot.encryption_configured?,
      required_scopes: required_scopes,
      approval_notes: approval_notes,
      capabilities: capabilities.to_h
    }
  end

  private

  def http_connection(host)
    Faraday.new(url: "https://#{host}") do |conn|
      conn.options.timeout = HTTP_TIMEOUT
      conn.options.open_timeout = HTTP_OPEN_TIMEOUT
    end
  end

  def parse_json(body)
    JSON.parse(body.to_s)
  rescue JSON::ParserError
    raise GlintReach::Social::Error::TokenExchangeFailed, 'Malformed JSON response from provider'
  end
end
