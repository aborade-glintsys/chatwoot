module Enterprise::Audit::GlintReach::Approval
  extend ActiveSupport::Concern

  included do
    audited associated_with: :account
  end
end
