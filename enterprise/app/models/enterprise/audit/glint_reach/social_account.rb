module Enterprise::Audit::GlintReach::SocialAccount
  extend ActiveSupport::Concern

  included do
    # Never record OAuth tokens in audit logs.
    audited associated_with: :account, except: [:access_token, :refresh_token]
  end
end
