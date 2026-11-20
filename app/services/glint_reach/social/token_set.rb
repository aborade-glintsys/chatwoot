# Normalized OAuth token bundle returned by a provider adapter.
GlintReach::Social::TokenSet = Data.define(
  :access_token,
  :refresh_token,
  :expires_at,
  :refresh_expires_at,
  :scopes,
  :id_token
)
