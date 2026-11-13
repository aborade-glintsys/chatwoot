import { defineStore } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import { toClient, toServer, rethrowApiError } from './helpers';

const emptyMeta = () => ({ count: 0, currentPage: 1 });

export const useGlintReachCampaignsStore = defineStore('glintReachCampaigns', {
  state: () => ({
    records: [],
    meta: emptyMeta(),
    filters: { status: '', search: '', page: 1 },
    current: null,
    uiFlags: { isFetching: false, isFetchingItem: false, isSaving: false },
    fetchRequestToken: 0,
  }),

  actions: {
    async fetchCampaigns(filters = {}) {
      this.filters = { ...this.filters, ...filters };
      this.uiFlags.isFetching = true;
      this.fetchRequestToken += 1;
      const requestToken = this.fetchRequestToken;
      try {
        const { data } = await GlintReachAPI.getCampaigns(this.filters);
        // A newer filter/page change superseded this request.
        if (requestToken !== this.fetchRequestToken) return this.records;
        this.records = toClient(data.payload);
        this.meta = toClient(data.meta);
        return this.records;
      } catch (error) {
        if (requestToken !== this.fetchRequestToken) return this.records;
        this.records = [];
        this.meta = emptyMeta();
        return rethrowApiError(error);
      } finally {
        if (requestToken === this.fetchRequestToken) {
          this.uiFlags.isFetching = false;
        }
      }
    },

    async fetchCampaign(id) {
      this.uiFlags.isFetchingItem = true;
      this.current = null;
      try {
        const { data } = await GlintReachAPI.getCampaign(id);
        this.current = toClient(data);
        return this.current;
      } catch (error) {
        return rethrowApiError(error);
      } finally {
        this.uiFlags.isFetchingItem = false;
      }
    },

    async createCampaign(attributes) {
      this.uiFlags.isSaving = true;
      try {
        const { data } = await GlintReachAPI.createCampaign(
          toServer(attributes)
        );
        this.current = toClient(data);
        return this.current;
      } catch (error) {
        return rethrowApiError(error);
      } finally {
        this.uiFlags.isSaving = false;
      }
    },

    async updateCampaign(id, attributes) {
      this.uiFlags.isSaving = true;
      try {
        const { data } = await GlintReachAPI.updateCampaign(
          id,
          toServer(attributes)
        );
        this.current = toClient(data);
        const index = this.records.findIndex(record => record.id === id);
        if (index !== -1) {
          const { contentItems, ...summary } = this.current;
          this.records.splice(index, 1, summary);
        }
        return this.current;
      } catch (error) {
        return rethrowApiError(error);
      } finally {
        this.uiFlags.isSaving = false;
      }
    },

    replaceVariant(variant) {
      const item = this.current?.contentItems?.find(
        contentItem => contentItem.id === variant.contentItemId
      );
      if (!item) return;
      const index = item.variants.findIndex(v => v.id === variant.id);
      if (index !== -1) item.variants.splice(index, 1, variant);
    },

    async updateVariant(target, attributes) {
      try {
        const { data } = await GlintReachAPI.updateVariant(
          target,
          toServer(attributes)
        );
        const variant = toClient(data);
        this.replaceVariant(variant);
        return variant;
      } catch (error) {
        return rethrowApiError(error);
      }
    },

    async transitionVariant(target, status) {
      try {
        const { data } = await GlintReachAPI.transitionVariant(target, status);
        const variant = toClient(data);
        this.replaceVariant(variant);
        return variant;
      } catch (error) {
        return rethrowApiError(error);
      }
    },

    // Reloads the open campaign without blanking it (used after AI writes content).
    async refreshCurrent() {
      if (!this.current) return null;
      try {
        const { data } = await GlintReachAPI.getCampaign(this.current.id);
        this.current = toClient(data);
      } catch {
        // Keep showing the last loaded data.
      }
      return this.current;
    },

    reset() {
      this.$reset();
    },
  },
});
