import { defineStore } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import { toClient, toServer, rethrowApiError } from './helpers';

export const useGlintReachBrandProfileStore = defineStore(
  'glintReachBrandProfile',
  {
    state: () => ({
      profile: null,
      hasLoaded: false,
      uiFlags: { isFetching: false, isSaving: false },
    }),

    actions: {
      async fetch() {
        this.uiFlags.isFetching = true;
        try {
          const { data } = await GlintReachAPI.getBrandProfile();
          this.profile = toClient(data.brand_profile);
          this.hasLoaded = true;
          return this.profile;
        } catch (error) {
          return rethrowApiError(error);
        } finally {
          this.uiFlags.isFetching = false;
        }
      },

      async save(attributes) {
        this.uiFlags.isSaving = true;
        try {
          const { data } = await GlintReachAPI.saveBrandProfile(
            toServer(attributes)
          );
          this.profile = toClient(data.brand_profile);
          this.hasLoaded = true;
          return this.profile;
        } catch (error) {
          return rethrowApiError(error);
        } finally {
          this.uiFlags.isSaving = false;
        }
      },

      reset() {
        this.$reset();
      },
    },
  }
);
