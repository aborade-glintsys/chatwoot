module Enterprise::Audit::GlintReach::Schedule
  extend ActiveSupport::Concern

  included do
    audited associated_with: :account
  end
end
