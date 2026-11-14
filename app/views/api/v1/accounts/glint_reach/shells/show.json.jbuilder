json.product_name 'GlintReach'
json.tagline 'Create once. Reach everywhere.'
json.ai_configured GlintReach::Ai::ProviderResolver.configured?(Current.account)
# Account reporting time zone (IANA) used as the default for calendars and scheduling; nil = browser zone.
json.timezone Current.account.reporting_timezone.presence && ActiveSupport::TimeZone[Current.account.reporting_timezone]&.tzinfo&.name
json.modules @modules do |module_key|
  json.key module_key
  json.available Api::V1::Accounts::GlintReach::ShellsController::AVAILABLE_MODULES.include?(module_key)
end
