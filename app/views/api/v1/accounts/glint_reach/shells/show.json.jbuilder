json.product_name 'GlintReach'
json.tagline 'Create once. Reach everywhere.'
json.ai_configured GlintReach::Ai::ProviderResolver.configured?(Current.account)
json.modules @modules do |module_key|
  json.key module_key
  json.available Api::V1::Accounts::GlintReach::ShellsController::AVAILABLE_MODULES.include?(module_key)
end
