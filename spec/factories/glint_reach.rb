FactoryBot.define do
  factory :glint_reach_campaign, class: 'GlintReach::Campaign' do
    account
    created_by { association :user, account: account, role: :administrator }
    sequence(:name) { |n| "Campaign #{n}" }
    objective { :awareness }
  end

  factory :glint_reach_brand_profile, class: 'GlintReach::BrandProfile' do
    account
    name { 'Acme Outdoors' }
    website_url { 'https://acme.example' }
    preferred_languages { %w[en] }
    approved_ctas { ['Shop now'] }
  end

  factory :glint_reach_content_item, class: 'GlintReach::ContentItem' do
    campaign factory: :glint_reach_campaign
    sequence(:title) { |n| "Content #{n}" }
    content_type { :post }
  end

  factory :glint_reach_content_variant, class: 'GlintReach::ContentVariant' do
    content_item factory: :glint_reach_content_item
    platform { :instagram }
    body { 'Launch day is here' }
  end
end
