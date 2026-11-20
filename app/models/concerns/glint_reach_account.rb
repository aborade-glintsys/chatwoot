module GlintReachAccount
  extend ActiveSupport::Concern

  included do
    has_many :glint_reach_campaigns, dependent: :destroy_async, class_name: 'GlintReach::Campaign'
    # One brand profile per account for now (unique index on account_id).
    has_one :glint_reach_brand_profile, dependent: :destroy_async, class_name: 'GlintReach::BrandProfile'
    has_many :glint_reach_social_accounts, dependent: :destroy_async, class_name: 'GlintReach::SocialAccount'
  end
end
