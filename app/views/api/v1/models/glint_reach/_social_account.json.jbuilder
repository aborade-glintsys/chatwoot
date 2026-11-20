# OAuth access/refresh tokens are intentionally never serialized.
effective_status = social_account.connected? && social_account.token_expired? ? 'expired' : social_account.status

json.id social_account.id
json.account_id social_account.account_id
json.provider social_account.provider
json.provider_account_id social_account.provider_account_id
json.provider_account_type social_account.provider_account_type
json.display_name social_account.display_name
json.profile_url social_account.profile_url
json.avatar_url social_account.avatar_url
json.granted_scopes social_account.granted_scopes
json.status effective_status
json.token_expires_at social_account.token_expires_at&.to_i
json.refresh_expires_at social_account.refresh_expires_at&.to_i
json.last_error_code social_account.last_error_code
json.last_error_message social_account.last_error_message
json.last_verified_at social_account.last_verified_at&.to_i
json.capabilities social_account.capabilities.to_h
json.connected_by do
  json.id social_account.connected_by_id
  json.name social_account.connected_by&.name
end
json.created_at social_account.created_at.to_i
json.updated_at social_account.updated_at.to_i
