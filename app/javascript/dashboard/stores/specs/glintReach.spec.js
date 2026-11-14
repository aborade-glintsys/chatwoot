import { setActivePinia, createPinia } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import { useGlintReachBrandProfileStore } from '../glintReach/brandProfile';
import { useGlintReachCampaignsStore } from '../glintReach/campaigns';
import { GlintReachValidationError } from '../glintReach/helpers';

vi.mock('dashboard/api/glintReach', () => ({
  default: {
    getBrandProfile: vi.fn(),
    saveBrandProfile: vi.fn(),
    getCampaigns: vi.fn(),
    getCampaign: vi.fn(),
    createCampaign: vi.fn(),
    updateCampaign: vi.fn(),
  },
}));

const unprocessable = attributes => ({
  response: {
    status: 422,
    data: { message: 'Website url is invalid', attributes },
  },
});

describe('GlintReach stores', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  describe('brand profile', () => {
    it('stores null when the account has no profile', async () => {
      GlintReachAPI.getBrandProfile.mockResolvedValue({
        data: { brand_profile: null },
      });
      const store = useGlintReachBrandProfileStore();

      await store.fetch();

      expect(store.profile).toBeNull();
      expect(store.hasLoaded).toBe(true);
    });

    it('camelizes the profile and snake_cases the save payload', async () => {
      GlintReachAPI.saveBrandProfile.mockResolvedValue({
        data: {
          brand_profile: {
            id: 1,
            name: 'Acme',
            website_url: 'https://acme.example',
            approved_ctas: ['Shop now'],
          },
        },
      });
      const store = useGlintReachBrandProfileStore();

      await store.save({
        name: 'Acme',
        websiteUrl: 'https://acme.example',
        approvedCtas: ['Shop now'],
      });

      expect(GlintReachAPI.saveBrandProfile).toHaveBeenCalledWith({
        name: 'Acme',
        website_url: 'https://acme.example',
        approved_ctas: ['Shop now'],
      });
      expect(store.profile).toMatchObject({
        websiteUrl: 'https://acme.example',
        approvedCtas: ['Shop now'],
      });
      expect(store.uiFlags.isSaving).toBe(false);
    });

    it('rethrows 422 errors with camelCased attribute names', async () => {
      GlintReachAPI.saveBrandProfile.mockRejectedValue(
        unprocessable(['website_url', 'preferred_languages'])
      );
      const store = useGlintReachBrandProfileStore();

      const error = await store.save({ name: 'x' }).catch(e => e);

      expect(error).toBeInstanceOf(GlintReachValidationError);
      expect(error.message).toBe('Website url is invalid');
      expect(error.attributes).toEqual(['websiteUrl', 'preferredLanguages']);
      expect(store.profile).toBeNull();
    });

    it('reset clears cached data', async () => {
      const store = useGlintReachBrandProfileStore();
      store.profile = { id: 1 };
      store.hasLoaded = true;

      store.reset();

      expect(store.profile).toBeNull();
      expect(store.hasLoaded).toBe(false);
    });
  });

  describe('campaigns', () => {
    it('fetches a filtered page and stores meta', async () => {
      GlintReachAPI.getCampaigns.mockResolvedValue({
        data: {
          meta: { count: 1, current_page: 2 },
          payload: [{ id: 3, name: 'Launch', starts_at: null }],
        },
      });
      const store = useGlintReachCampaignsStore();

      await store.fetchCampaigns({ page: 2, status: 'draft', search: 'La' });

      expect(GlintReachAPI.getCampaigns).toHaveBeenCalledWith({
        page: 2,
        status: 'draft',
        search: 'La',
      });
      expect(store.records).toEqual([
        { id: 3, name: 'Launch', startsAt: null },
      ]);
      expect(store.meta).toEqual({ count: 1, currentPage: 2 });
    });

    it('clears records when a fetch fails', async () => {
      GlintReachAPI.getCampaigns.mockRejectedValue({
        response: { data: { error: 'GlintReach is not enabled' } },
      });
      const store = useGlintReachCampaignsStore();
      store.records = [{ id: 1 }];

      await expect(store.fetchCampaigns()).rejects.toThrow(
        'GlintReach is not enabled'
      );
      expect(store.records).toEqual([]);
    });

    it('updates the current campaign with snake_cased brief fields', async () => {
      GlintReachAPI.updateCampaign.mockResolvedValue({
        data: {
          id: 5,
          name: 'Launch',
          key_message: 'Built to last',
          channels: ['instagram'],
          content_items: [],
        },
      });
      const store = useGlintReachCampaignsStore();
      store.records = [{ id: 5, name: 'Old' }];

      await store.updateCampaign(5, {
        keyMessage: 'Built to last',
        channels: ['instagram'],
      });

      expect(GlintReachAPI.updateCampaign).toHaveBeenCalledWith(5, {
        key_message: 'Built to last',
        channels: ['instagram'],
      });
      expect(store.current.keyMessage).toBe('Built to last');
      expect(store.records[0]).toEqual({
        id: 5,
        name: 'Launch',
        keyMessage: 'Built to last',
        channels: ['instagram'],
      });
    });

    it('rethrows 422 errors from create', async () => {
      GlintReachAPI.createCampaign.mockRejectedValue(
        unprocessable(['channels'])
      );
      const store = useGlintReachCampaignsStore();

      const error = await store.createCampaign({ name: 'x' }).catch(e => e);

      expect(error.attributes).toEqual(['channels']);
      expect(store.uiFlags.isSaving).toBe(false);
    });
  });
});
