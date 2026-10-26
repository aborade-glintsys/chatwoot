module Enterprise::Audit::GlintReach::BrandProfile
  extend ActiveSupport::Concern

  included do
    audited associated_with: :account
  end
end
