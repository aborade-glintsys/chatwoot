import { reactive } from 'vue';
import { shallowMount, flushPromises } from '@vue/test-utils';
import { useRoute } from 'vue-router';
import { usePolicy } from 'dashboard/composables/usePolicy';
import GlintReachAPI from 'dashboard/api/glintReach';
import GlintReachRouteView from '../pages/GlintReachRouteView.vue';
import { setActivePinia, createPinia } from 'pinia';
import { useGlintReachBrandProfileStore } from 'dashboard/stores/glintReach/brandProfile';

vi.mock('dashboard/composables/usePolicy');
vi.mock('dashboard/api/glintReach', () => ({
  default: { getShell: vi.fn() },
}));
vi.mock('vue-router', () => ({ useRoute: vi.fn() }));

const mountView = () =>
  shallowMount(GlintReachRouteView, {
    global: {
      stubs: { 'router-view': { template: '<div class="child" />' } },
    },
  });

describe('GlintReachRouteView', () => {
  let flagEnabled;
  let route;

  beforeEach(() => {
    setActivePinia(createPinia());
    flagEnabled = true;
    route = reactive({ params: { accountId: '1' } });
    useRoute.mockReturnValue(route);
    usePolicy.mockReturnValue({ isFeatureFlagEnabled: () => flagEnabled });
    GlintReachAPI.getShell.mockReset();
  });

  it('shows the disabled state and skips the API when the flag is off', async () => {
    flagEnabled = false;
    const wrapper = mountView();
    await flushPromises();

    expect(GlintReachAPI.getShell).not.toHaveBeenCalled();
    expect(wrapper.find('.child').exists()).toBe(false);
    expect(
      wrapper.findComponent({ name: 'EmptyStateLayout' }).props('title')
    ).toBe('GLINT_REACH.DISABLED.TITLE');
  });

  it('shows the disabled state when the server denies access', async () => {
    GlintReachAPI.getShell.mockRejectedValue({ response: { status: 403 } });
    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.find('.child').exists()).toBe(false);
    expect(wrapper.findComponent({ name: 'EmptyStateLayout' }).exists()).toBe(
      true
    );
  });

  it('renders the child route once the server confirms access', async () => {
    GlintReachAPI.getShell.mockResolvedValue({
      data: { product_name: 'GlintReach', modules: [] },
    });
    const wrapper = mountView();
    await flushPromises();

    expect(GlintReachAPI.getShell).toHaveBeenCalledTimes(1);
    expect(wrapper.find('.child').exists()).toBe(true);
  });

  it('drops cached GlintReach data when the account changes', async () => {
    GlintReachAPI.getShell.mockResolvedValue({ data: { modules: [] } });
    mountView();
    await flushPromises();
    const store = useGlintReachBrandProfileStore();
    store.profile = { id: 1, name: 'Account 1 brand' };

    route.params.accountId = '2';
    await flushPromises();

    expect(store.profile).toBeNull();
    expect(GlintReachAPI.getShell).toHaveBeenCalledTimes(2);
  });
});
