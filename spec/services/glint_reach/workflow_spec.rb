require 'rails_helper'

RSpec.describe GlintReach::Workflow do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account, role: :administrator) }
  let(:reviewer) { create(:user, account: account, role: :administrator) }
  let(:campaign) { create(:glint_reach_campaign, account: account, created_by: author) }
  let(:item) { create(:glint_reach_content_item, campaign: campaign) }
  let(:variant) { create(:glint_reach_content_variant, content_item: item, body: 'Launch day') }
  let(:tomorrow) { 1.day.from_now.utc }

  def workflow(user = author, target = variant, lock_version: nil)
    described_class.new(variant: target, user: user, lock_version: lock_version)
  end

  def approve!(target = variant)
    workflow(author, target).submit!
    workflow(reviewer, target).review!(decision: 'approved')
  end

  def schedule!(user = author, target = variant, at: tomorrow)
    workflow(user, target).schedule!(date: at.to_date.iso8601, time: at.strftime('%H:%M'), timezone: 'UTC')
  end

  describe 'submit and review' do
    it 'moves draft -> in_review -> approved and records the approval' do
      workflow.submit!
      expect(variant.reload).to have_attributes(status: 'in_review', submitted_by_id: author.id)

      workflow(reviewer).review!(decision: 'approved', feedback: 'Looks good')
      approval = variant.approvals.last
      expect(variant.reload).to be_approved
      expect(approval).to have_attributes(decision: 'approved', reviewer_id: reviewer.id, feedback: 'Looks good',
                                          content_digest: variant.content_digest, account_id: account.id)
    end

    it 'requires feedback when requesting changes and allows resubmission' do
      workflow.submit!
      expect { workflow(reviewer).review!(decision: 'changes_requested') }.to raise_error(ActiveRecord::RecordInvalid)

      workflow(reviewer).review!(decision: 'changes_requested', feedback: 'Shorter please')
      expect(variant.reload).to be_changes_requested
      variant.update!(body: 'Short')
      workflow.submit!
      expect(variant.reload).to be_in_review
    end

    it 'forbids self-approval' do
      workflow.submit!
      expect { workflow(author).review!(decision: 'approved') }.to raise_error(described_class::Forbidden, /another administrator/)
      expect(variant.reload).to be_in_review
      expect(variant.approvals).to be_empty
    end

    it 'refuses to submit empty content' do
      variant.update!(body: '')
      expect { workflow.submit! }.to raise_error(described_class::Conflict, /post text/)
    end

    it 'rejects invalid transitions' do
      expect { workflow(reviewer).review!(decision: 'approved') }.to raise_error(described_class::Conflict, /cannot move/)
      expect { workflow.withdraw! }.to raise_error(described_class::Conflict)
      expect { workflow.cancel_schedule! }.to raise_error(described_class::Conflict)
      expect { schedule! }.to raise_error(described_class::Conflict)
    end

    it 'rejects unknown decisions' do
      workflow.submit!
      expect { workflow(reviewer).review!(decision: 'maybe') }.to raise_error(described_class::Conflict)
    end

    it 'detects stale lock versions' do
      stale = variant.lock_version
      variant.update!(body: 'Edited elsewhere')
      expect { workflow(author, variant, lock_version: stale).submit! }.to raise_error(described_class::Conflict, /someone else/)
    end

    it 'blocks actions on locked campaigns' do
      campaign.update_columns(status: GlintReach::Campaign.statuses[:archived]) # rubocop:disable Rails/SkipsModelValidations
      expect { workflow.submit! }.to raise_error(described_class::Conflict, /completed or archived/)
    end

    it 'reopen voids the approval for scheduling' do
      approve!
      workflow.reopen!
      expect(variant.reload).to have_attributes(status: 'draft', submitted_by_id: nil)
      variant.update!(body: 'Edited after reopen')
      workflow.submit!
      expect { schedule! }.to raise_error(described_class::Conflict)
    end
  end

  describe 'scheduling' do
    before { approve! }

    it 'schedules approved content once and stores the UTC time and zone' do
      workflow.schedule!(date: tomorrow.to_date.iso8601, time: '09:30', timezone: 'Asia/Kolkata')

      schedule = variant.schedules.sole
      expect(variant.reload).to be_scheduled
      expect(schedule).to have_attributes(status: 'pending', timezone: 'Asia/Kolkata', approval_id: variant.approvals.last.id)
      expect(schedule.scheduled_at).to eq(ActiveSupport::TimeZone['Asia/Kolkata'].parse("#{tomorrow.to_date} 09:30").utc)
    end

    it 'reschedules the same schedule instead of creating another' do
      schedule!
      later = tomorrow + 2.hours
      schedule!(author, variant, at: later)

      expect(variant.schedules.count).to eq(1)
      expect(variant.schedules.sole.scheduled_at).to eq(later.change(sec: 0))
    end

    it 'refuses to schedule content that changed after approval' do
      GlintReach::ContentVariant.where(id: variant.id).update_all(body: 'Sneaky edit') # rubocop:disable Rails/SkipsModelValidations
      expect { schedule! }.to raise_error(described_class::Conflict, /changed after it was approved/)
    end

    it 'converts schedule time errors into conflicts' do
      expect { workflow.schedule!(date: '2020-01-01', time: '10:00', timezone: 'UTC') }.to raise_error(described_class::Conflict, /minutes/)
    end

    it 'cancels a pending schedule back to approved' do
      schedule!
      workflow.cancel_schedule!
      expect(variant.reload).to be_approved
      expect(variant.schedules.sole).to be_cancelled
    end

    it 'allows cancelling even when the campaign became locked' do
      schedule!
      campaign.update_columns(status: GlintReach::Campaign.statuses[:archived]) # rubocop:disable Rails/SkipsModelValidations
      workflow.cancel_schedule!
      expect(variant.reload).to be_approved
    end

    it 'refuses to cancel once dispatch has started' do
      schedule!
      variant.schedules.sole.update!(status: :dispatching)
      expect { workflow.cancel_schedule! }.to raise_error(described_class::Conflict, /already started/)
      expect(variant.reload).to be_scheduled
    end

    it 'enforces one live schedule per variant at the database level' do
      schedule!
      approval = variant.approvals.last
      expect do
        GlintReach::Schedule.create!(content_variant: variant, approval: approval, scheduled_by: author,
                                     scheduled_at: tomorrow, timezone: 'UTC')
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'leaves exactly one schedule when two schedule calls race' do
      variant_copy = GlintReach::ContentVariant.find(variant.id)
      schedule!
      # The second caller loaded the variant before the first finished; the row lock makes it see
      # `scheduled` and reschedule rather than insert a second live row.
      schedule!(reviewer, variant_copy, at: tomorrow + 1.hour)
      expect(variant.schedules.live.count).to eq(1)
    end
  end

  describe '#permissions' do
    it 'reflects state and the no-self-review rule' do
      expect(workflow.permissions).to include(edit: true, submit: true, review: false, schedule: false)
      workflow.submit!
      expect(workflow(author, variant.reload).permissions).to include(review: false, withdraw: true, edit: false)
      expect(workflow(reviewer, variant).permissions).to include(review: true)
    end
  end
end
