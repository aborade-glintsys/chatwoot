import { mount, flushPromises } from '@vue/test-utils';
import { setActivePinia, createPinia } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import {
  useGlintReachGenerationsStore,
  POLL_INTERVAL_MS,
} from 'dashboard/stores/glintReach/generations';
import AiGenerationPanel from '../components/AiGenerationPanel.vue';
import VariantCard from '../components/VariantCard.vue';
import GenerationStatus from '../components/GenerationStatus.vue';

vi.mock('dashboard/api/glintReach', () => ({
  default: {
    getGenerations: vi.fn(),
    getGeneration: vi.fn(),
    createGeneration: vi.fn(),
    getCampaign: vi.fn(),
    updateVariant: vi.fn(),
    transitionVariant: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const queued = (overrides = {}) => ({
  id: 1,
  kind: 'strategy',
  status: 'queued',
  content_item_id: null,
  content_variant_id: null,
  ...overrides,
});

beforeEach(() => {
  setActivePinia(createPinia());
  vi.clearAllMocks();
});

describe('generations store', () => {
  afterEach(() => vi.useRealTimers());

  it('sends snake_case params and polls until the generation settles', async () => {
    vi.useFakeTimers();
    GlintReachAPI.getGenerations.mockResolvedValue({ data: { payload: [] } });
    GlintReachAPI.createGeneration.mockResolvedValue({ data: queued() });
    GlintReachAPI.getGeneration
      .mockResolvedValueOnce({ data: queued({ status: 'generating' }) })
      .mockResolvedValueOnce({ data: queued({ status: 'completed' }) });
    const onSettled = vi.fn();
    const store = useGlintReachGenerationsStore();

    await store.load(7, onSettled);
    await store.request({ kind: 'variants', contentItemId: 3 });
    expect(GlintReachAPI.createGeneration).toHaveBeenCalledWith(7, {
      kind: 'variants',
      content_item_id: 3,
    });

    await vi.advanceTimersByTimeAsync(POLL_INTERVAL_MS);
    expect(store.records[0].status).toBe('generating');
    expect(onSettled).not.toHaveBeenCalled();

    await vi.advanceTimersByTimeAsync(POLL_INTERVAL_MS);
    expect(store.records[0].status).toBe('completed');
    expect(onSettled).toHaveBeenCalledTimes(1);

    await vi.advanceTimersByTimeAsync(POLL_INTERVAL_MS * 3);
    expect(GlintReachAPI.getGeneration).toHaveBeenCalledTimes(2);
  });

  it('does not call onSettled for failures and stops polling on reset', async () => {
    vi.useFakeTimers();
    GlintReachAPI.getGenerations.mockResolvedValue({
      data: { payload: [queued()] },
    });
    GlintReachAPI.getGeneration.mockResolvedValue({
      data: queued({ status: 'failed', error_message: 'Rate limited' }),
    });
    const onSettled = vi.fn();
    const store = useGlintReachGenerationsStore();
    await store.load(7, onSettled);

    await vi.advanceTimersByTimeAsync(POLL_INTERVAL_MS);
    expect(store.records[0].errorMessage).toBe('Rate limited');
    expect(onSettled).not.toHaveBeenCalled();

    store.reset();
    await vi.advanceTimersByTimeAsync(POLL_INTERVAL_MS * 3);
    expect(GlintReachAPI.getGeneration).toHaveBeenCalledTimes(1);
  });

  it('surfaces server rejection messages', async () => {
    GlintReachAPI.getGenerations.mockResolvedValue({ data: { payload: [] } });
    GlintReachAPI.createGeneration.mockRejectedValue({
      response: { data: { error: 'AI is not configured.' } },
    });
    const store = useGlintReachGenerationsStore();
    await store.load(7);

    await expect(store.request({ kind: 'strategy' })).rejects.toThrow(
      'AI is not configured.'
    );
    expect(store.records).toEqual([]);
  });
});

describe('GenerationStatus', () => {
  it('shows the failure message with a retry button', async () => {
    const wrapper = mount(GenerationStatus, {
      props: { generation: { status: 'failed', errorMessage: 'Try later' } },
    });
    expect(wrapper.text()).toContain('Try later');
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('retry')).toHaveLength(1);
  });

  it('renders nothing for completed generations without skips', () => {
    const wrapper = mount(GenerationStatus, {
      props: { generation: { status: 'completed', result: {} } },
    });
    expect(wrapper.text()).toBe('');
  });
});

describe('AiGenerationPanel', () => {
  const campaign = {
    id: 7,
    strategy: {
      positioning: '<img src=x onerror=alert(1)>',
      keyMessages: ['Light'],
      contentPillars: [{ name: 'Trails', description: 'Local' }],
      channelApproach: [],
    },
  };

  it('renders strategy text safely and requests generations', async () => {
    GlintReachAPI.createGeneration.mockResolvedValue({ data: queued() });
    useGlintReachGenerationsStore().campaignId = 7;
    const wrapper = mount(AiGenerationPanel, {
      props: { campaign, enabled: true },
    });

    expect(wrapper.find('[data-testid="campaign-strategy"] img').exists()).toBe(
      false
    );
    expect(wrapper.text()).toContain('<img src=x onerror=alert(1)>');

    await wrapper.find('[data-testid="plan-count"]').setValue(50);
    await wrapper.find('[data-testid="generate-plan"]').trigger('click');
    expect(GlintReachAPI.createGeneration).toHaveBeenCalledWith(7, {
      kind: 'content_plan',
      count: 10,
    });
  });

  it('disables actions when AI is not enabled', () => {
    const wrapper = mount(AiGenerationPanel, {
      props: { campaign, enabled: false },
    });
    expect(
      wrapper.find('[data-testid="generate-strategy"]').attributes('disabled')
    ).toBeDefined();
  });
});

describe('VariantCard', () => {
  const variant = {
    id: 5,
    contentItemId: 3,
    platform: 'instagram',
    body: 'Hello',
    callToAction: null,
    hashtags: [],
    status: 'draft',
  };
  const mountCard = (props = {}) =>
    mount(VariantCard, {
      props: {
        variant,
        campaignId: 7,
        canEdit: true,
        aiEnabled: true,
        ...props,
      },
    });

  it('requests a rewrite with the instruction', async () => {
    GlintReachAPI.createGeneration.mockResolvedValue({
      data: queued({ kind: 'rewrite', content_variant_id: 5 }),
    });
    useGlintReachGenerationsStore().campaignId = 7;
    const wrapper = mountCard();

    await wrapper.find('[data-testid="variant-rewrite"]').trigger('click');
    await wrapper
      .find('[data-testid="rewrite-instruction"]')
      .setValue('Make it shorter');
    await wrapper.find('[data-testid="rewrite-form"]').trigger('submit');
    await flushPromises();

    expect(GlintReachAPI.createGeneration).toHaveBeenCalledWith(7, {
      kind: 'rewrite',
      content_variant_id: 5,
      instruction: 'Make it shorter',
    });
  });

  it('blocks instructions over 500 characters', async () => {
    const wrapper = mountCard();
    await wrapper.find('[data-testid="variant-rewrite"]').trigger('click');
    await wrapper
      .find('[data-testid="rewrite-instruction"]')
      .setValue('a'.repeat(501));
    await wrapper.find('[data-testid="rewrite-form"]').trigger('submit');

    expect(wrapper.text()).toContain(
      'GLINT_REACH.AI.VARIANT.INSTRUCTION_TOO_LONG'
    );
    expect(GlintReachAPI.createGeneration).not.toHaveBeenCalled();
  });

  it('protects ready variants from regenerate and rewrite', () => {
    const wrapper = mountCard({ variant: { ...variant, status: 'ready' } });
    expect(
      wrapper.find('[data-testid="variant-regenerate"]').attributes('disabled')
    ).toBeDefined();
    expect(
      wrapper.find('[data-testid="variant-rewrite"]').attributes('disabled')
    ).toBeDefined();
    expect(wrapper.text()).toContain('GLINT_REACH.AI.VARIANT.READY_HINT');
  });

  it('saves manual edits through the variant API', async () => {
    GlintReachAPI.updateVariant.mockResolvedValue({
      data: { ...variant, body: 'Edited', content_item_id: 3 },
    });
    const wrapper = mountCard();
    await wrapper.find('button').trigger('click');
    await wrapper.find('textarea').setValue('Edited');
    await wrapper.find('[data-testid="variant-editor"]').trigger('submit');
    await flushPromises();

    expect(GlintReachAPI.updateVariant).toHaveBeenCalledWith(
      { campaignId: 7, contentItemId: 3, variantId: 5 },
      expect.objectContaining({ body: 'Edited' })
    );
  });
});
