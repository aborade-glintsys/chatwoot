require 'rails_helper'

RSpec.describe GlintReach::Workflow::ScheduleTime do
  let(:now) { Time.utc(2026, 3, 1, 12, 0) }

  def parse(date:, time:, timezone:, campaign: nil, at: now)
    described_class.parse(date: date, time: time, timezone: timezone, campaign: campaign, now: at)
  end

  it 'converts wall-clock time in an IANA zone to UTC' do
    expect(parse(date: '2026-03-02', time: '09:30', timezone: 'Asia/Kolkata')).to eq(Time.utc(2026, 3, 2, 4, 0))
  end

  it 'handles local times that fall on the previous UTC day' do
    expect(parse(date: '2026-03-03', time: '02:00', timezone: 'Asia/Kolkata')).to eq(Time.utc(2026, 3, 2, 20, 30))
  end

  it 'handles local times that fall on the next UTC day' do
    expect(parse(date: '2026-03-02', time: '22:00', timezone: 'America/Los_Angeles')).to eq(Time.utc(2026, 3, 3, 6, 0))
  end

  it 'rejects times skipped by a DST change (spring forward)' do
    expect { parse(date: '2026-03-08', time: '02:30', timezone: 'America/New_York') }
      .to raise_error(described_class::Invalid, /does not exist/)
  end

  it 'resolves repeated times (fall back) to the first occurrence' do
    result = parse(date: '2026-11-01', time: '01:30', timezone: 'America/New_York', at: Time.utc(2026, 10, 1))
    expect(result).to eq(Time.utc(2026, 11, 1, 5, 30)) # 01:30 EDT, not 01:30 EST (06:30 UTC)
  end

  it 'is unaffected by the server time zone' do
    Time.use_zone('Pacific/Auckland') do
      expect(parse(date: '2026-03-02', time: '09:30', timezone: 'UTC')).to eq(Time.utc(2026, 3, 2, 9, 30))
    end
  end

  it 'rejects invalid zones, dates and times' do
    expect { parse(date: '2026-03-02', time: '09:30', timezone: 'Mars/Base') }.to raise_error(described_class::Invalid, /time zone/)
    expect { parse(date: '2026-02-30', time: '09:30', timezone: 'UTC') }.to raise_error(described_class::Invalid, /valid date/)
    expect { parse(date: '2026-03-02', time: '24:00', timezone: 'UTC') }.to raise_error(described_class::Invalid, /valid time/)
    expect { parse(date: '2026-03-02', time: '9:30', timezone: 'UTC') }.to raise_error(described_class::Invalid, /valid time/)
  end

  it 'requires at least 5 minutes of lead time' do
    expect { parse(date: '2026-03-01', time: '12:04', timezone: 'UTC') }.to raise_error(described_class::Invalid, /5 minutes/)
    expect(parse(date: '2026-03-01', time: '12:05', timezone: 'UTC')).to eq(Time.utc(2026, 3, 1, 12, 5))
  end

  it 'rejects times more than a year ahead' do
    expect { parse(date: '2027-03-02', time: '12:00', timezone: 'UTC') }.to raise_error(described_class::Invalid, /one year/)
  end

  it 'keeps the time inside the campaign dates' do
    campaign = build(:glint_reach_campaign, starts_at: Time.utc(2026, 3, 5), ends_at: Time.utc(2026, 3, 10, 23, 59))

    expect { parse(date: '2026-03-04', time: '23:00', timezone: 'UTC', campaign: campaign) }
      .to raise_error(described_class::Invalid, /before the campaign/)
    expect { parse(date: '2026-03-11', time: '00:00', timezone: 'UTC', campaign: campaign) }
      .to raise_error(described_class::Invalid, /after the campaign/)
    expect(parse(date: '2026-03-06', time: '10:00', timezone: 'UTC', campaign: campaign)).to be_present
  end
end
