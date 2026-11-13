import { mount, flushPromises } from '@vue/test-utils';
import { setActivePinia, createPinia } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import { useGlintReachAssetsStore } from 'dashboard/stores/glintReach/assets';
import AssetsPanel from '../components/AssetsPanel.vue';
import AssetPicker from '../components/AssetPicker.vue';
import AssetFileButton from '../components/AssetFileButton.vue';
import {
  precheckAssetFile,
  ASSET_MAX_BYTES,
  formatBytes,
} from '../helpers/assets';

vi.mock('dashboard/api/glintReach', () => ({
  default: {
    getAssets: vi.fn(),
    uploadAsset: vi.fn(),
    updateAsset: vi.fn(),
    deleteAsset: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const DialogStub = {
  name: 'Dialog',
  emits: ['confirm', 'close'],
  template: '<div><slot /></div>',
  methods: { open() {}, close() {} },
};
const global = { stubs: { Dialog: DialogStub } };

const serverAsset = (id, overrides = {}) => ({
  id,
  filename: `image-${id}.png`,
  content_type: 'image/png',
  byte_size: 2048,
  width: 400,
  height: 300,
  alt_text: null,
  url: `/rails/active_storage/blobs/redirect/s${id}/image.png`,
  thumbnail_url: `/rails/active_storage/representations/redirect/s${id}/v/image.png`,
  ...overrides,
});
const listResponse = assets => ({
  data: { payload: assets, meta: { count: assets.length, current_page: 1 } },
});
const makeFile = (type = 'image/png', size = 1024) => {
  const file = new File(['x'], 'pic.png', { type });
  Object.defineProperty(file, 'size', { value: size });
  return file;
};

beforeEach(() => {
  setActivePinia(createPinia());
  vi.clearAllMocks();
});

describe('asset helpers', () => {
  it('pre-checks type and size', () => {
    expect(precheckAssetFile(null)).toBe('GLINT_REACH.ASSETS.ERRORS.MISSING');
    expect(precheckAssetFile(makeFile('image/svg+xml'))).toBe(
      'GLINT_REACH.ASSETS.ERRORS.TYPE'
    );
    expect(precheckAssetFile(makeFile('image/png', ASSET_MAX_BYTES + 1))).toBe(
      'GLINT_REACH.ASSETS.ERRORS.SIZE'
    );
    expect(precheckAssetFile(makeFile())).toBeNull();
    expect(formatBytes(2 * 1024 * 1024)).toBe('2.0 MB');
  });
});

describe('AssetFileButton', () => {
  const choose = async (wrapper, file) => {
    const input = wrapper.find('[data-testid="asset-file-input"]');
    Object.defineProperty(input.element, 'files', { value: [file] });
    await input.trigger('change');
  };

  it('emits valid files and rejects unsupported ones', async () => {
    const wrapper = mount(AssetFileButton, { props: { label: 'Upload' } });
    await choose(wrapper, makeFile());
    expect(wrapper.emitted('select')).toHaveLength(1);

    const second = mount(AssetFileButton, { props: { label: 'Upload' } });
    await choose(second, makeFile('application/pdf'));
    expect(second.emitted('select')).toBeUndefined();
    expect(second.emitted('invalid')[0][0]).toBe(
      'GLINT_REACH.ASSETS.ERRORS.TYPE'
    );
  });
});

describe('assets store', () => {
  it('loads, uploads, updates and removes', async () => {
    GlintReachAPI.getAssets.mockResolvedValue(listResponse([serverAsset(1)]));
    GlintReachAPI.uploadAsset.mockResolvedValue({ data: serverAsset(2) });
    GlintReachAPI.updateAsset.mockResolvedValue({
      data: serverAsset(1, { alt_text: 'Hero' }),
    });
    GlintReachAPI.deleteAsset.mockResolvedValue({});
    const store = useGlintReachAssetsStore();

    await store.load(7);
    expect(store.records[0].thumbnailUrl).toContain('representations');

    const file = makeFile();
    await store.upload(file, 'Alt');
    expect(GlintReachAPI.uploadAsset).toHaveBeenCalledWith(7, {
      file,
      altText: 'Alt',
    });
    expect(store.records.map(r => r.id)).toEqual([2, 1]);

    await store.update(1, { altText: 'Hero' });
    expect(store.records[1].altText).toBe('Hero');

    await store.remove(2);
    expect(store.records.map(r => r.id)).toEqual([1]);
    expect(store.count).toBe(1);
  });

  it('surfaces server validation messages', async () => {
    GlintReachAPI.getAssets.mockResolvedValue(listResponse([]));
    GlintReachAPI.uploadAsset.mockRejectedValue({
      response: { data: { message: 'File is not a JPEG, PNG, WebP or GIF' } },
    });
    const store = useGlintReachAssetsStore();
    await store.load(7);

    await expect(store.upload(makeFile())).rejects.toThrow('not a JPEG');
    expect(store.records).toEqual([]);
  });
});

describe('AssetsPanel', () => {
  it('shows the empty state', async () => {
    GlintReachAPI.getAssets.mockResolvedValue(listResponse([]));
    const wrapper = mount(AssetsPanel, {
      global,
      props: { campaignId: 7, canEdit: true },
    });
    await flushPromises();
    expect(wrapper.find('[data-testid="assets-empty"]').exists()).toBe(true);
  });

  it('renders previews with alt text and hides edit controls when locked', async () => {
    GlintReachAPI.getAssets.mockResolvedValue(
      listResponse([serverAsset(1, { alt_text: '<b>Hero</b>' })])
    );
    const wrapper = mount(AssetsPanel, {
      global,
      props: { campaignId: 7, canEdit: false },
    });
    await flushPromises();

    const img = wrapper.find('[data-testid="asset-1"] img');
    expect(img.attributes('alt')).toBe('<b>Hero</b>');
    expect(wrapper.find('[data-testid="asset-1"] b').exists()).toBe(false);
    expect(wrapper.find('[data-testid="asset-remove-1"]').exists()).toBe(false);
  });

  it('shows the server error when an upload is rejected', async () => {
    GlintReachAPI.getAssets.mockResolvedValue(listResponse([]));
    GlintReachAPI.uploadAsset.mockRejectedValue({
      response: { data: { message: 'Images must be at least 200 pixels' } },
    });
    const wrapper = mount(AssetsPanel, {
      global,
      props: { campaignId: 7, canEdit: true },
    });
    await flushPromises();

    wrapper.findComponent(AssetFileButton).vm.$emit('select', makeFile());
    await flushPromises();
    expect(wrapper.find('[data-testid="assets-error"]').text()).toContain(
      'at least 200 pixels'
    );
  });
});

describe('AssetPicker', () => {
  it('keeps selection order, respects the maximum and emits ids', async () => {
    GlintReachAPI.getAssets.mockResolvedValue(
      listResponse([serverAsset(1), serverAsset(2), serverAsset(3)])
    );
    const wrapper = mount(AssetPicker, {
      global,
      props: { campaignId: 7, max: 2 },
    });
    await wrapper.vm.open([]);
    await flushPromises();

    await wrapper.find('[data-testid="picker-asset-3"]').trigger('click');
    await wrapper.find('[data-testid="picker-asset-1"]').trigger('click');
    expect(
      wrapper.find('[data-testid="picker-asset-2"]').attributes('disabled')
    ).toBeDefined();

    wrapper.findComponent(DialogStub).vm.$emit('confirm');
    expect(wrapper.emitted('select')[0][0]).toEqual([3, 1]);
  });

  it('starts from the current selection and can deselect', async () => {
    GlintReachAPI.getAssets.mockResolvedValue(
      listResponse([serverAsset(1), serverAsset(2)])
    );
    const wrapper = mount(AssetPicker, { global, props: { campaignId: 7 } });
    await wrapper.vm.open([2]);
    await flushPromises();

    await wrapper.find('[data-testid="picker-asset-2"]').trigger('click');
    wrapper.findComponent(DialogStub).vm.$emit('confirm');
    expect(wrapper.emitted('select')[0][0]).toEqual([]);
  });
});
