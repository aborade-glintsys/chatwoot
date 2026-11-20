json.payload @social_accounts do |social_account|
  json.partial! 'api/v1/models/glint_reach/social_account', formats: [:json], social_account: social_account
end
