require 'rails_helper'

RSpec.describe GlintReach::BrandProfile do
  let(:account) { create(:account) }

  def build_profile(**attrs)
    build(:glint_reach_brand_profile, account: account, **attrs)
  end

  it 'is valid with the factory defaults' do
    expect(build_profile).to be_valid
  end

  it 'requires a name of at most 255 characters' do
    expect(build_profile(name: '')).not_to be_valid
    expect(build_profile(name: 'a' * 256)).not_to be_valid
  end

  it 'limits long text fields to 5,000 characters' do
    described_class::TEXT_FIELDS.each do |field|
      profile = build_profile(field => 'a' * 5_001)
      expect(profile).not_to be_valid
      expect(profile.errors[field]).to be_present
    end
    expect(build_profile(description: 'a' * 5_000)).to be_valid
  end

  it 'allows only one profile per account' do
    create(:glint_reach_brand_profile, account: account)

    profile = build_profile
    expect(profile).not_to be_valid
    expect(profile.errors[:account_id]).to be_present
  end

  describe 'website_url' do
    it 'accepts absolute http and https URLs and blank values' do
      ['https://acme.example/path?q=1', 'http://acme.example', '', nil].each do |url|
        expect(build_profile(website_url: url)).to be_valid
      end
    end

    it 'rejects other schemes, relative URLs, credentials and malformed values' do
      ['javascript:alert(1)', 'ftp://acme.example', 'acme.example', '/about', 'https://', 'https://user:pw@acme.example',
       'http://exa mple.com'].each do |url|
        profile = build_profile(website_url: url)
        expect(profile).not_to be_valid, "expected #{url.inspect} to be invalid"
        expect(profile.errors[:website_url]).to be_present
      end
    end

    it 'rejects URLs longer than 2,048 characters' do
      expect(build_profile(website_url: "https://acme.example/#{'a' * 2050}")).not_to be_valid
    end

    it 'strips surrounding whitespace' do
      profile = build_profile(website_url: '  https://acme.example  ')
      profile.validate
      expect(profile.website_url).to eq('https://acme.example')
    end
  end

  describe 'preferred_languages' do
    it 'normalizes and de-duplicates codes' do
      profile = build_profile(preferred_languages: [' en ', 'en', '', 'pt-BR'])
      expect(profile).to be_valid
      expect(profile.preferred_languages).to eq(%w[en pt-BR])
    end

    it 'rejects invalid codes and more than 10 languages' do
      expect(build_profile(preferred_languages: ['english'])).not_to be_valid
      expect(build_profile(preferred_languages: ['<script>'])).not_to be_valid
      expect(build_profile(preferred_languages: %w[aa ab ae af ak am an ar as av ay])).not_to be_valid
    end
  end

  describe 'approved_ctas' do
    it 'squishes and de-duplicates entries' do
      profile = build_profile(approved_ctas: ['  Shop   now ', 'Shop now', ''])
      expect(profile).to be_valid
      expect(profile.approved_ctas).to eq(['Shop now'])
    end

    it 'rejects more than 20 CTAs or entries over 100 characters' do
      expect(build_profile(approved_ctas: (1..21).map { |i| "CTA #{i}" })).not_to be_valid
      profile = build_profile(approved_ctas: ['a' * 101])
      expect(profile).not_to be_valid
      expect(profile.errors[:approved_ctas].first).to eq('entries must be at most 100 characters')
    end
  end

  it 'stores markup as plain text without modification' do
    profile = create(:glint_reach_brand_profile, account: account, description: '<img src=x onerror=alert(1)>')
    expect(profile.reload.description).to eq('<img src=x onerror=alert(1)>')
  end
end
