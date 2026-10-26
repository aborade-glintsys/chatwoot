require 'rails_helper'

RSpec.describe GlintReach::Campaign do
  let(:account) { create(:account) }
  let(:creator) { create(:user, account: account, role: :administrator) }

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(build(:glint_reach_campaign, account: account, created_by: creator)).to be_valid
    end

    it 'requires a name and objective' do
      campaign = described_class.new(account: account, created_by: creator)

      expect(campaign).not_to be_valid
      expect(campaign.errors.attribute_names).to include(:name, :objective)
    end

    it 'rejects an unknown objective' do
      campaign = build(:glint_reach_campaign, account: account, created_by: creator, objective: 'unknown')

      expect(campaign).not_to be_valid
      expect(campaign.errors[:objective]).to be_present
    end

    it 'requires ends_at to be after starts_at' do
      campaign = build(:glint_reach_campaign, account: account, created_by: creator, starts_at: 1.day.from_now, ends_at: 1.hour.from_now)

      expect(campaign).not_to be_valid
      expect(campaign.errors[:ends_at]).to include('must be after the start time')
    end

    it 'rejects a creator from another account' do
      outsider = create(:user, account: create(:account), role: :administrator)
      campaign = build(:glint_reach_campaign, account: account, created_by: outsider)

      expect(campaign).not_to be_valid
      expect(campaign.errors[:created_by]).to include('must be a member of the account')
    end

    it 'defaults to draft' do
      expect(create(:glint_reach_campaign, account: account, created_by: creator)).to be_draft
    end
  end

  describe '#transition_to!' do
    let(:campaign) { create(:glint_reach_campaign, account: account, created_by: creator) }

    allowed = {
      'draft' => %w[active archived],
      'active' => %w[paused completed],
      'paused' => %w[active completed archived],
      'completed' => %w[archived]
    }
    statuses = described_class.statuses.keys

    allowed.each do |from, targets|
      targets.each do |to|
        it "allows #{from} -> #{to}" do
          campaign.update_column(:status, described_class.statuses[from]) # rubocop:disable Rails/SkipsModelValidations
          campaign.transition_to!(to)

          expect(campaign.reload.status).to eq(to)
        end
      end

      (statuses - targets).each do |to|
        it "rejects #{from} -> #{to}" do
          campaign.update_column(:status, described_class.statuses[from]) # rubocop:disable Rails/SkipsModelValidations

          expect { campaign.transition_to!(to) }.to raise_error(ActiveRecord::RecordInvalid, /cannot change from #{from} to #{to}/)
          expect(campaign.reload.status).to eq(from)
        end
      end
    end

    it 'allows no transitions out of archived' do
      campaign.update_column(:status, described_class.statuses['archived']) # rubocop:disable Rails/SkipsModelValidations

      expect { campaign.transition_to!('draft') }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'search_by_name' do
    it 'matches case-insensitively and treats wildcards literally' do
      match = create(:glint_reach_campaign, account: account, created_by: creator, name: 'Spring 100% Sale')
      create(:glint_reach_campaign, account: account, created_by: creator, name: 'Spring launch')

      expect(described_class.search_by_name('100%')).to eq([match])
      expect(described_class.search_by_name('spring').count).to eq(2)
    end
  end
end
