class Api::V1::Accounts::GlintReach::ShellsController < Api::V1::Accounts::GlintReach::BaseController
  MODULES = %w[overview brand_profile campaigns content_studio calendar social_accounts analytics].freeze
  AVAILABLE_MODULES = %w[overview brand_profile campaigns content_studio calendar social_accounts].freeze

  def show
    @modules = MODULES
  end
end
