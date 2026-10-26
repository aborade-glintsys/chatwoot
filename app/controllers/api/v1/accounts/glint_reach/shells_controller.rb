class Api::V1::Accounts::GlintReach::ShellsController < Api::V1::Accounts::GlintReach::BaseController
  MODULES = %w[overview campaigns content_studio calendar social_accounts analytics].freeze

  def show
    @modules = MODULES
  end
end
