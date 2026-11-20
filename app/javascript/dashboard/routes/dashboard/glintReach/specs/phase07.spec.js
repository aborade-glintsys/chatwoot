import { mount, flushPromises } from '@vue/test-utils';
import { setActivePinia, createPinia } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import { useGlintReachSocialAccountsStore } from 'dashboard/stores/glintReach/socialAccounts';
import GlintReachSocialAccountsPage from '../pages/GlintReachSocialAccountsPage.vue';
import {
  variantCapabilityWarnings,
  daysUntilExpiry,
} from '../helpers/capabilities';

vi.mock('dashboard/api/glintReach', () => ({
  default: {
    getSocialProviders: vi.fn(),
    getSocialAccounts: vi.fn(),
    authorizeSocialAccount: vi.fn(),
    disconnectSocialAccount: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const routeQuery = {};
const replace = vi.fn();
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: routeQuery }),
  useRouter: () => ({ replace }),
}));

const DialogStub = {
  name: 'Dialog',
  emits: ['confirm', 'close'],
  template: '<div><slot /></div>',
  methods: { open() {}, close() {} },
};
const global = { stubs: { Dialog: DialogStub } };

const linkedinProvider = (overrides = {}) => ({
  key: 'linkedin',
  display_name: 'LinkedIn',
  configured: true,
  encryption_configured: true,
  connectable: true,
  required_scopes: ['openid', 'profile', 'w_member_social'],
  approval_notes: 'Self-serve products required.',
  capabilities: {
    post_types: ['text', 'image'],
    max_text_length: 3000,
    max_images: 1,
    image_mime_types: ['image/jpeg', 'image/png', 'image/gif'],
    supports_video: false,
    supports_scheduling_natively: false,
    supports_refresh: false,
    token_lifetime_days: 60,
  },
  ...overrides,
});

const socialAccount = (overrides = {}) => ({
  id: 11,
  provider: 'linkedin',
  provider_account_id: 'mem-1',
  provider_account_type: 'member',
  display_name: 'Ada Lovelace',
  granted_scopes: ['openid', 'profile', 'w_member_social'],
  status: 'connected',
  token_expires_at: Math.floor(Date.now() / 1000) + 45 * 86400,
  last_error_message: null,
  ...overrides,
});

beforeEach(() => {
  setActivePinia(createPinia());
  vi.clearAllMocks();
  Object.keys(routeQuery).forEach(k => delete routeQuery[k]);
});

describe('capability helpers', () => {
  const caps = { maxTextLength: 3000, maxImages: 1 };

  it('flags text length and image count over provider limits', () => {
    expect(
      variantCapabilityWarnings({ body: 'Hello', assetIds: [1] }, caps)
    ).toEqual([]);

    const warnings = variantCapabilityWarnings(
      { body: 'a'.repeat(3001), assetIds: [1, 2] },
      caps
    );
    expect(warnings.map(w => w.key)).toEqual([
      'TEXT_TOO_LONG',
      'TOO_MANY_IMAGES',
    ]);
  });

  it('computes days until expiry', () => {
    expect(daysUntilExpiry(null)).toBeNull();
    expect(daysUntilExpiry(Math.floor(Date.now() / 1000) + 5 * 86400)).toBe(5);
  });
});

describe('socialAccounts store', () => {
  it('loads providers and accounts and handles disconnect', async () => {
    GlintReachAPI.getSocialProviders.mockResolvedValue({
      data: { payload: [linkedinProvider()] },
    });
    GlintReachAPI.getSocialAccounts.mockResolvedValue({
      data: { payload: [socialAccount()] },
    });
    GlintReachAPI.disconnectSocialAccount.mockResolvedValue({
      data: socialAccount({ status: 'revoked' }),
    });

    const store = useGlintReachSocialAccountsStore();
    await store.fetchAll();
    expect(store.providers[0].capabilities.maxImages).toBe(1);
    expect(store.connectedForProvider('linkedin')).toHaveLength(1);

    await store.disconnect(11);
    expect(store.accounts[0].status).toBe('revoked');
    expect(store.connectedForProvider('linkedin')).toHaveLength(0);
  });
});

describe('GlintReachSocialAccountsPage', () => {
  it('disables connect and shows encryption warning when encryption is missing', async () => {
    GlintReachAPI.getSocialProviders.mockResolvedValue({
      data: {
        payload: [
          linkedinProvider({
            encryption_configured: false,
            connectable: false,
          }),
        ],
      },
    });
    GlintReachAPI.getSocialAccounts.mockResolvedValue({
      data: { payload: [] },
    });

    const wrapper = mount(GlintReachSocialAccountsPage, { global });
    await flushPromises();

    expect(
      wrapper.find('[data-testid="provider-encryption-warning"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="connect-linkedin"]').attributes('disabled')
    ).toBeDefined();
    expect(wrapper.find('[data-testid="social-accounts-empty"]').exists()).toBe(
      true
    );
  });

  it('renders callback banner, connected account status and disconnect action', async () => {
    routeQuery.oauth = 'connected';
    GlintReachAPI.getSocialProviders.mockResolvedValue({
      data: { payload: [linkedinProvider()] },
    });
    GlintReachAPI.getSocialAccounts.mockResolvedValue({
      data: { payload: [socialAccount()] },
    });
    GlintReachAPI.disconnectSocialAccount.mockResolvedValue({
      data: socialAccount({ status: 'revoked' }),
    });

    const wrapper = mount(GlintReachSocialAccountsPage, { global });
    await flushPromises();

    expect(
      wrapper.find('[data-testid="social-callback-banner"]').text()
    ).toContain('GLINT_REACH.SOCIAL.CALLBACK.CONNECTED');
    expect(replace).toHaveBeenCalled();

    await wrapper.find('[data-testid="disconnect-11"]').trigger('click');
    wrapper.findComponent(DialogStub).vm.$emit('confirm');
    await flushPromises();
    expect(GlintReachAPI.disconnectSocialAccount).toHaveBeenCalledWith(11);
  });

  it('shows reconnect button for expired or missing-scope accounts', async () => {
    GlintReachAPI.getSocialProviders.mockResolvedValue({
      data: { payload: [linkedinProvider()] },
    });
    GlintReachAPI.getSocialAccounts.mockResolvedValue({
      data: { payload: [socialAccount({ status: 'missing_scopes' })] },
    });

    const wrapper = mount(GlintReachSocialAccountsPage, { global });
    await flushPromises();
    expect(wrapper.find('[data-testid="reconnect-11"]').exists()).toBe(true);
  });
});
