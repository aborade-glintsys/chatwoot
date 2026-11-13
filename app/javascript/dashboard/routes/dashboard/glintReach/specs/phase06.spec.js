import { mount, flushPromises } from '@vue/test-utils';
import { setActivePinia, createPinia } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import { useGlintReachCalendarStore } from 'dashboard/stores/glintReach/calendar';
import WorkflowPanel from '../components/WorkflowPanel.vue';
import ScheduleDialog from '../components/ScheduleDialog.vue';
import CalendarView from '../components/CalendarView.vue';
import ApprovalQueue from '../components/ApprovalQueue.vue';
import {
  daysFor,
  rangeFor,
  shiftAnchor,
  dayKeyIn,
  timeIn,
  groupByDay,
  formatInstant,
} from '../helpers/calendar';

vi.mock('dashboard/api/glintReach', () => ({
  default: {
    variantWorkflow: vi.fn(),
    getCalendar: vi.fn(),
    getApprovals: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const DialogStub = {
  name: 'Dialog',
  emits: ['confirm', 'close'],
  template: '<div><slot /></div>',
  methods: { open() {}, close() {} },
};
const global = {
  stubs: { Dialog: DialogStub },
  provide: { glintReachShell: { value: { timezone: 'Asia/Kolkata' } } },
};

const variant = (overrides = {}) => ({
  id: 5,
  contentItemId: 3,
  platform: 'instagram',
  status: 'draft',
  lockVersion: 2,
  editable: true,
  body: 'Hello',
  hashtags: [],
  permissions: {
    edit: true,
    submit: true,
    withdraw: false,
    review: false,
    reopen: false,
    schedule: false,
    cancelSchedule: false,
  },
  ...overrides,
});

beforeEach(() => {
  setActivePinia(createPinia());
  vi.clearAllMocks();
});

describe('calendar helpers', () => {
  it('builds Monday-first month grids covering whole weeks', () => {
    const days = daysFor('month', '2026-03-15');
    expect(days[0]).toBe('2026-02-23');
    expect(days[days.length - 1]).toBe('2026-04-05');
    expect(days.length % 7).toBe(0);
    expect(rangeFor('week', '2026-03-15')).toEqual({
      from: '2026-03-09',
      to: '2026-03-15',
    });
    expect(rangeFor('day', '2026-03-15')).toEqual({
      from: '2026-03-15',
      to: '2026-03-15',
    });
  });

  it('navigates by view', () => {
    expect(shiftAnchor('month', '2026-01-31', 1)).toBe('2026-02-28');
    expect(shiftAnchor('week', '2026-03-15', -1)).toBe('2026-03-08');
    expect(shiftAnchor('day', '2026-12-31', 1)).toBe('2027-01-01');
  });

  it('places instants on the local day of the chosen zone', () => {
    const epoch = Date.UTC(2026, 4, 10, 23, 30) / 1000;
    expect(dayKeyIn(epoch, 'UTC')).toBe('2026-05-10');
    expect(dayKeyIn(epoch, 'Asia/Kolkata')).toBe('2026-05-11');
    expect(timeIn(epoch, 'Asia/Kolkata')).toBe('05:00');
    expect(dayKeyIn(epoch, 'America/Los_Angeles')).toBe('2026-05-10');
    const groups = groupByDay([{ id: 1, scheduledAt: epoch }], 'Asia/Kolkata');
    expect(Object.keys(groups)).toEqual(['2026-05-11']);
  });

  it('handles DST transitions in local labels', () => {
    // 2026-03-08 07:30 UTC = 03:30 EDT (just after the spring-forward gap).
    const epoch = Date.UTC(2026, 2, 8, 7, 30) / 1000;
    expect(timeIn(epoch, 'America/New_York')).toBe('03:30');
  });
});

describe('WorkflowPanel', () => {
  it('shows only permitted actions and sends lock_version', async () => {
    const runner = vi.fn().mockResolvedValue(variant({ status: 'in_review' }));
    const wrapper = mount(WorkflowPanel, {
      global,
      props: { variant: variant(), campaignId: 7, runner },
    });

    expect(wrapper.find('[data-testid="workflow-review"]').exists()).toBe(
      false
    );
    expect(
      wrapper.find('[data-testid="workflow-schedule-button"]').exists()
    ).toBe(false);
    await wrapper.find('[data-testid="workflow-submit"]').trigger('click');
    await flushPromises();

    expect(runner).toHaveBeenCalledWith(
      { campaignId: 7, contentItemId: 3, variantId: 5 },
      'submit',
      { lock_version: 2 }
    );
  });

  it('requires feedback before requesting changes', async () => {
    const runner = vi
      .fn()
      .mockResolvedValue(variant({ status: 'changes_requested' }));
    const wrapper = mount(WorkflowPanel, {
      global,
      props: {
        variant: variant({
          status: 'in_review',
          permissions: { review: true },
        }),
        campaignId: 7,
        runner,
      },
    });
    await wrapper.find('[data-testid="workflow-review"]').trigger('click');
    await wrapper
      .find('[data-testid="workflow-request-changes"]')
      .trigger('click');
    expect(runner).not.toHaveBeenCalled();

    await wrapper
      .find('[data-testid="workflow-feedback-input"]')
      .setValue('Shorter');
    await wrapper
      .find('[data-testid="workflow-request-changes"]')
      .trigger('click');
    await flushPromises();
    expect(runner).toHaveBeenCalledWith(expect.any(Object), 'review', {
      lock_version: 2,
      decision: 'changes_requested',
      feedback: 'Shorter',
    });
  });

  it('explains self-review and shows the schedule with its zone', () => {
    const wrapper = mount(WorkflowPanel, {
      global,
      props: {
        variant: variant({
          status: 'scheduled',
          permissions: { schedule: true, cancelSchedule: true },
          schedule: {
            status: 'pending',
            scheduledAt: Date.UTC(2026, 4, 10, 3, 30) / 1000,
            timezone: 'Asia/Kolkata',
          },
        }),
        campaignId: 7,
        runner: vi.fn(),
      },
    });
    expect(wrapper.find('[data-testid="workflow-schedule"]').exists()).toBe(
      true
    );
    expect(
      formatInstant(Date.UTC(2026, 4, 10, 3, 30) / 1000, 'Asia/Kolkata')
    ).toContain('09:00');
    expect(wrapper.find('[data-testid="workflow-cancel"]').exists()).toBe(true);

    const selfReview = mount(WorkflowPanel, {
      global,
      props: {
        variant: variant({
          status: 'in_review',
          permissions: { withdraw: true, review: false },
        }),
        campaignId: 7,
        runner: vi.fn(),
      },
    });
    expect(
      selfReview.find('[data-testid="workflow-self-review-hint"]').exists()
    ).toBe(true);
  });

  it('shows server schedule errors inside the dialog', async () => {
    const runner = vi
      .fn()
      .mockRejectedValue(new Error('That time does not exist'));
    const wrapper = mount(WorkflowPanel, {
      global,
      props: {
        variant: variant({
          status: 'approved',
          permissions: { schedule: true },
        }),
        campaignId: 7,
        runner,
      },
    });
    wrapper.findComponent(ScheduleDialog).vm.$emit('submit', {
      date: '2026-03-08',
      time: '02:30',
      timezone: 'America/New_York',
    });
    await flushPromises();
    expect(runner).toHaveBeenCalledWith(expect.any(Object), 'schedule', {
      lock_version: 2,
      date: '2026-03-08',
      time: '02:30',
      timezone: 'America/New_York',
    });
    expect(wrapper.find('[data-testid="schedule-error"]').text()).toContain(
      'does not exist'
    );
  });
});

describe('ScheduleDialog', () => {
  it('defaults to the account timezone and emits explicit values', async () => {
    const wrapper = mount(ScheduleDialog, { global });
    wrapper.vm.open();
    await flushPromises();
    expect(
      wrapper.find('[data-testid="schedule-timezone"]').element.value
    ).toBe('Asia/Kolkata');

    await wrapper.find('[data-testid="schedule-date"]').setValue('2026-05-11');
    await wrapper.find('[data-testid="schedule-time"]').setValue('05:00');
    wrapper.findComponent(DialogStub).vm.$emit('confirm');
    expect(wrapper.emitted('submit')[0][0]).toEqual({
      date: '2026-05-11',
      time: '05:00',
      timezone: 'Asia/Kolkata',
    });
  });

  it('prefills an existing schedule in its own zone', async () => {
    const wrapper = mount(ScheduleDialog, { global });
    wrapper.vm.open({
      scheduledAt: Date.UTC(2026, 4, 10, 23, 30) / 1000,
      timezone: 'Asia/Kolkata',
    });
    await flushPromises();
    expect(wrapper.find('[data-testid="schedule-date"]').element.value).toBe(
      '2026-05-11'
    );
    expect(wrapper.find('[data-testid="schedule-time"]').element.value).toBe(
      '05:00'
    );
  });
});

describe('CalendarView', () => {
  const item = {
    id: 9,
    status: 'pending',
    scheduledAt: Date.UTC(2026, 4, 10, 23, 30) / 1000,
    variant: { platform: 'x' },
    contentItem: { title: 'Launch teaser' },
    campaign: { id: 7, name: 'Spring' },
  };

  it('renders items on the local day and emits navigation', async () => {
    const wrapper = mount(CalendarView, {
      props: {
        items: [item],
        view: 'month',
        anchor: '2026-05-15',
        today: '2026-05-13',
        timezone: 'Asia/Kolkata',
      },
    });
    expect(
      wrapper
        .find(
          '[data-testid="calendar-day-2026-05-11"] [data-testid="calendar-item-9"]'
        )
        .exists()
    ).toBe(true);
    expect(
      wrapper
        .find(
          '[data-testid="calendar-day-2026-05-10"] [data-testid="calendar-item-9"]'
        )
        .exists()
    ).toBe(false);

    await wrapper.find('[data-testid="calendar-next"]').trigger('click');
    await wrapper.find('[data-testid="calendar-view-week"]').trigger('click');
    await wrapper.find('[data-testid="calendar-item-9"]').trigger('click');
    expect(wrapper.emitted('navigate')[0]).toEqual([1]);
    expect(wrapper.emitted('update:view')[0]).toEqual(['week']);
    expect(wrapper.emitted('open')[0][0].id).toBe(9);
  });

  it('shows the empty state', () => {
    const wrapper = mount(CalendarView, {
      props: {
        items: [],
        view: 'day',
        anchor: '2026-05-15',
        today: '2026-05-15',
        timezone: 'UTC',
      },
    });
    expect(wrapper.find('[data-testid="calendar-empty"]').exists()).toBe(true);
  });
});

describe('ApprovalQueue', () => {
  it('lists pending reviews and removes decided items', async () => {
    GlintReachAPI.getApprovals.mockResolvedValue({
      data: {
        meta: { count: 1, current_page: 1 },
        payload: [
          {
            id: 5,
            content_item_id: 3,
            platform: 'instagram',
            status: 'in_review',
            lock_version: 1,
            body: '<b>Hi</b>',
            hashtags: [],
            assets: [],
            permissions: { review: true },
            content_item: { id: 3, title: 'Teaser' },
            campaign: { id: 7, name: 'Spring' },
            submitted_by: { id: 1, name: 'Ann' },
          },
        ],
      },
    });
    GlintReachAPI.variantWorkflow.mockResolvedValue({
      data: { id: 5, status: 'approved', content_item_id: 3 },
    });
    const wrapper = mount(ApprovalQueue, { global });
    await flushPromises();

    expect(wrapper.find('[data-testid="approval-5"]').text()).toContain(
      '<b>Hi</b>'
    );
    await wrapper.find('[data-testid="workflow-review"]').trigger('click');
    await wrapper
      .find('[data-testid="workflow-review-form"]')
      .trigger('submit');
    await flushPromises();

    expect(GlintReachAPI.variantWorkflow).toHaveBeenCalledWith(
      { campaignId: 7, contentItemId: 3, variantId: 5 },
      'review',
      { lock_version: 1, decision: 'approved', feedback: '' }
    );
    expect(useGlintReachCalendarStore().approvals).toEqual([]);
    expect(wrapper.find('[data-testid="approval-queue-empty"]').exists()).toBe(
      true
    );
  });
});
