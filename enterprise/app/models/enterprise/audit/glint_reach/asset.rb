module Enterprise::Audit::GlintReach::Asset
  extend ActiveSupport::Concern

  included do
    audited associated_with: :account, except: [:checksum]
  end
end
