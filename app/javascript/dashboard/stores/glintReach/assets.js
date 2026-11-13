import { defineStore } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import { toClient, rethrowApiError } from './helpers';

// Assets of the open campaign. Asset URLs are short-lived signed paths, so the
// list is re-fetched whenever the picker or panel needs fresh previews.
export const useGlintReachAssetsStore = defineStore('glintReachAssets', {
  state: () => ({
    campaignId: null,
    records: [],
    count: 0,
    uiFlags: { isFetching: false, isUploading: false, savingId: null },
  }),

  actions: {
    async load(campaignId) {
      this.campaignId = campaignId;
      this.uiFlags.isFetching = true;
      try {
        const { data } = await GlintReachAPI.getAssets(campaignId);
        if (this.campaignId !== campaignId) return this.records;
        this.records = toClient(data.payload);
        this.count = data.meta.count;
        return this.records;
      } catch (error) {
        return rethrowApiError(error);
      } finally {
        if (this.campaignId === campaignId) this.uiFlags.isFetching = false;
      }
    },

    async upload(file, altText) {
      this.uiFlags.isUploading = true;
      try {
        const { data } = await GlintReachAPI.uploadAsset(this.campaignId, {
          file,
          altText,
        });
        const asset = toClient(data);
        this.records.unshift(asset);
        this.count += 1;
        return asset;
      } catch (error) {
        return rethrowApiError(error);
      } finally {
        this.uiFlags.isUploading = false;
      }
    },

    async update(id, attributes) {
      this.uiFlags.savingId = id;
      try {
        const { data } = await GlintReachAPI.updateAsset(
          this.campaignId,
          id,
          attributes
        );
        const asset = toClient(data);
        const index = this.records.findIndex(record => record.id === id);
        if (index !== -1) this.records.splice(index, 1, asset);
        return asset;
      } catch (error) {
        return rethrowApiError(error);
      } finally {
        this.uiFlags.savingId = null;
      }
    },

    async remove(id) {
      this.uiFlags.savingId = id;
      try {
        await GlintReachAPI.deleteAsset(this.campaignId, id);
        this.records = this.records.filter(record => record.id !== id);
        this.count = Math.max(0, this.count - 1);
      } catch (error) {
        rethrowApiError(error);
      } finally {
        this.uiFlags.savingId = null;
      }
    },

    reset() {
      this.$reset();
    },
  },
});
