import { mount, flushPromises } from '@vue/test-utils';
import { setActivePinia, createPinia } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import BrandProfileForm from '../components/BrandProfileForm.vue';
import CampaignBriefForm from '../components/CampaignBriefForm.vue';
import ContentItemsList from '../components/ContentItemsList.vue';
import GlintReachBrandProfilePage from '../pages/GlintReachBrandProfilePage.vue';
import GlintReachCampaignsPage from '../pages/GlintReachCampaignsPage.vue';

// Built at runtime so the no-script-url lint rule does not flag test data.
const SCRIPT_URL = ['javascript', 'alert(1)'].join(':');

vi.mock('dashboard/api/glintReach', () => ({
  default: {
    getBrandProfile: vi.fn(),
    saveBrandProfile: vi.fn(),
    getCampaigns: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
const push = vi.fn();
vi.mock('vue-router', () => ({ useRouter: () => ({ push }) }));

const global = { stubs: { 'router-link': { template: '<a><slot /></a>' } } };

describe('BrandProfileForm', () => {
  it('shows validation errors and does not submit invalid input', async () => {
    const wrapper = mount(BrandProfileForm, { global });
    await wrapper.find('#glint-reach-brand-website').setValue(SCRIPT_URL);
    await wrapper.find('form').trigger('submit');

    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(wrapper.text()).toContain('GLINT_REACH.VALIDATION.REQUIRED');
    expect(wrapper.text()).toContain('GLINT_REACH.VALIDATION.INVALID_URL');
  });

  it('submits trimmed values including list fields', async () => {
    const wrapper = mount(BrandProfileForm, {
      global,
      props: {
        profile: {
          name: 'Acme',
          approvedCtas: ['Shop now'],
          preferredLanguages: ['en'],
        },
      },
    });
    await wrapper.find('#glint-reach-brand-name').setValue('  Acme Outdoors ');
    await wrapper
      .find('#glint-reach-brand-website')
      .setValue('https://acme.example ');
    await wrapper.find('form').trigger('submit');

    const [payload] = wrapper.emitted('submit')[0];
    expect(payload).toMatchObject({
      name: 'Acme Outdoors',
      websiteUrl: 'https://acme.example',
      approvedCtas: ['Shop now'],
      preferredLanguages: ['en'],
    });
  });

  it('flags fields rejected by the server', () => {
    const wrapper = mount(BrandProfileForm, {
      global,
      props: {
        profile: { name: 'Acme' },
        serverMessage: 'Website url is invalid',
        serverErrorFields: ['websiteUrl'],
      },
    });

    expect(wrapper.find('[role="alert"]').text()).toBe(
      'Website url is invalid'
    );
    expect(wrapper.text()).toContain('GLINT_REACH.VALIDATION.SERVER_REJECTED');
  });

  it('adds approved CTAs with Enter and removes them', async () => {
    const wrapper = mount(BrandProfileForm, {
      global,
      props: { profile: { name: 'Acme' } },
    });
    const ctaInput = wrapper.find('input[enterkeyhint="done"]');
    await ctaInput.setValue('  Book   a demo ');
    await ctaInput.trigger('keydown', { key: 'Enter' });
    expect(wrapper.text()).toContain('Book a demo');

    await wrapper.find('form').trigger('submit');
    expect(wrapper.emitted('submit')[0][0].approvedCtas).toEqual([
      'Book a demo',
    ]);
  });
});

describe('CampaignBriefForm', () => {
  const campaign = {
    id: 1,
    name: 'Launch',
    objective: 'awareness',
    channels: ['instagram'],
    startsAt: null,
    endsAt: null,
  };

  it('requires a name and objective for a new campaign', async () => {
    const wrapper = mount(CampaignBriefForm, { global });
    await wrapper.find('form').trigger('submit');

    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(wrapper.text()).toContain('GLINT_REACH.VALIDATION.REQUIRED');
  });

  it('submits the brief with toggled channels and ISO dates', async () => {
    const wrapper = mount(CampaignBriefForm, { global, props: { campaign } });
    await wrapper
      .find('#glint-reach-brief-key-message')
      .setValue('Built to last');
    await wrapper.find('input[value="linkedin"]').trigger('change');
    await wrapper.find('#glint-reach-brief-starts-at').setValue('2026-11-01');
    await wrapper.find('#glint-reach-brief-ends-at').setValue('2026-11-30');
    await wrapper.find('form').trigger('submit');

    const [payload] = wrapper.emitted('submit')[0];
    expect(payload).toMatchObject({
      name: 'Launch',
      keyMessage: 'Built to last',
      channels: ['instagram', 'linkedin'],
      startsAt: '2026-11-01T00:00:00.000Z',
      endsAt: '2026-11-30T00:00:00.000Z',
    });
  });

  it('rejects an end date before the start date', async () => {
    const wrapper = mount(CampaignBriefForm, { global, props: { campaign } });
    await wrapper.find('#glint-reach-brief-starts-at').setValue('2026-11-30');
    await wrapper.find('#glint-reach-brief-ends-at').setValue('2026-11-01');
    await wrapper.find('form').trigger('submit');

    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(wrapper.text()).toContain('GLINT_REACH.VALIDATION.END_BEFORE_START');
  });

  it('is read-only and hides save when locked', async () => {
    const wrapper = mount(CampaignBriefForm, {
      global,
      props: { campaign, readonly: true },
    });

    expect(wrapper.find('fieldset').attributes('disabled')).toBeDefined();
    expect(wrapper.find('button[type="submit"]').exists()).toBe(false);
    await wrapper.find('form').trigger('submit');
    expect(wrapper.emitted('submit')).toBeUndefined();
  });
});

describe('ContentItemsList', () => {
  beforeEach(() => setActivePinia(createPinia()));

  it('shows an empty state without items', () => {
    const wrapper = mount(ContentItemsList, { global });
    expect(wrapper.find('[data-testid="content-items-empty"]').exists()).toBe(
      true
    );
  });

  it('renders untrusted text as plain text', () => {
    const wrapper = mount(ContentItemsList, {
      global,
      props: {
        items: [
          {
            id: 1,
            title: '<img src=x onerror=alert(1)>',
            contentType: 'post',
            status: 'draft',
            variants: [
              {
                id: 2,
                platform: 'x',
                status: 'approved',
                body: '<b>hi</b>',
                hashtags: ['launch'],
              },
            ],
          },
        ],
      },
    });
    expect(wrapper.find('img').exists()).toBe(false);
    expect(wrapper.find('b').exists()).toBe(false);
    expect(wrapper.text()).toContain('<img src=x onerror=alert(1)>');
    expect(wrapper.text()).toContain('#launch');
  });
});

describe('GlintReachBrandProfilePage', () => {
  beforeEach(() => setActivePinia(createPinia()));

  it('shows the empty state, then the form, then the saved profile', async () => {
    GlintReachAPI.getBrandProfile.mockResolvedValue({
      data: { brand_profile: null },
    });
    GlintReachAPI.saveBrandProfile.mockResolvedValue({
      data: {
        brand_profile: {
          id: 1,
          name: 'Acme',
          approved_ctas: [],
          preferred_languages: [],
        },
      },
    });
    const wrapper = mount(GlintReachBrandProfilePage, { global });
    await flushPromises();

    expect(wrapper.text()).toContain('GLINT_REACH.BRAND_PROFILE.EMPTY_TITLE');
    await wrapper.find('[data-testid="brand-profile-create"]').trigger('click');
    await wrapper.find('#glint-reach-brand-name').setValue('Acme');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(GlintReachAPI.saveBrandProfile).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'Acme' })
    );
    expect(wrapper.find('form').exists()).toBe(false);
    expect(wrapper.find('h2').text()).toBe('Acme');
  });

  it('keeps the form open and shows server errors on 422', async () => {
    GlintReachAPI.getBrandProfile.mockResolvedValue({
      data: {
        brand_profile: {
          id: 1,
          name: 'Acme',
          approved_ctas: [],
          preferred_languages: [],
        },
      },
    });
    GlintReachAPI.saveBrandProfile.mockRejectedValue({
      response: { data: { message: 'Name is too long', attributes: ['name'] } },
    });
    const wrapper = mount(GlintReachBrandProfilePage, { global });
    await flushPromises();

    await wrapper.find('[data-testid="brand-profile-edit"]').trigger('click');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(wrapper.find('form').exists()).toBe(true);
    expect(wrapper.text()).toContain('Name is too long');
    expect(wrapper.text()).toContain('GLINT_REACH.VALIDATION.SERVER_REJECTED');
  });

  it('shows a retry state when loading fails', async () => {
    GlintReachAPI.getBrandProfile.mockRejectedValue({
      response: {
        data: { error: 'GlintReach is not enabled for this account' },
      },
    });
    const wrapper = mount(GlintReachBrandProfilePage, { global });
    await flushPromises();

    expect(wrapper.text()).toContain(
      'GlintReach is not enabled for this account'
    );
    expect(wrapper.text()).toContain('GLINT_REACH.FORM.RETRY');
  });
});

describe('GlintReachCampaignsPage', () => {
  beforeEach(() => setActivePinia(createPinia()));

  it('shows the empty state when there are no campaigns', async () => {
    GlintReachAPI.getCampaigns.mockResolvedValue({
      data: { meta: { count: 0, current_page: 1 }, payload: [] },
    });
    const wrapper = mount(GlintReachCampaignsPage, { global });
    await flushPromises();

    expect(wrapper.text()).toContain('GLINT_REACH.CAMPAIGNS.EMPTY_TITLE');
  });

  it('lists campaigns and opens one in Content Studio', async () => {
    GlintReachAPI.getCampaigns.mockResolvedValue({
      data: {
        meta: { count: 1, current_page: 1 },
        payload: [
          { id: 9, name: 'Launch', objective: 'sales', status: 'draft' },
        ],
      },
    });
    const wrapper = mount(GlintReachCampaignsPage, { global });
    await flushPromises();

    await wrapper.find('[data-testid="campaign-list"] button').trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'glint_reach_content_studio_campaign',
      params: { campaignId: 9 },
    });
  });

  it('shows the no-results state when a status filter matches nothing', async () => {
    GlintReachAPI.getCampaigns.mockResolvedValue({
      data: { meta: { count: 0, current_page: 1 }, payload: [] },
    });
    const wrapper = mount(GlintReachCampaignsPage, { global });
    await flushPromises();
    await wrapper.find('#glint-reach-campaign-status').setValue('archived');
    await flushPromises();

    expect(GlintReachAPI.getCampaigns).toHaveBeenLastCalledWith({
      page: 1,
      status: 'archived',
      search: '',
    });
    expect(wrapper.text()).toContain('GLINT_REACH.CAMPAIGNS.NO_RESULTS_TITLE');
  });
});
