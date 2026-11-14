import { defineStore } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import { toClient, toServer, rethrowApiError } from './helpers';

export const POLL_INTERVAL_MS = 2000;
const ACTIVE_STATUSES = ['queued', 'generating'];

export const isActiveGeneration = generation =>
  ACTIVE_STATUSES.includes(generation?.status);

// Tracks AI generations for the open campaign. Active generations are polled
// every POLL_INTERVAL_MS until they complete or fail; `onSettled` lets the page
// reload campaign data when generated content has been written.
export const useGlintReachGenerationsStore = defineStore(
  'glintReachGenerations',
  {
    state: () => ({
      campaignId: null,
      records: [],
      isRequesting: false,
      pollTimer: null,
      onSettled: null,
    }),

    getters: {
      active: state => state.records.filter(isActiveGeneration),
      // Latest generation per target, used to show status next to the target.
      latestFor: state => target =>
        state.records.find(
          record =>
            record.kind === target.kind &&
            (record.contentItemId || null) === (target.contentItemId || null) &&
            (record.contentVariantId || null) ===
              (target.contentVariantId || null)
        ) || null,
    },

    actions: {
      async load(campaignId, onSettled = null) {
        this.stopPolling();
        this.campaignId = campaignId;
        this.onSettled = onSettled;
        this.records = [];
        try {
          const { data } = await GlintReachAPI.getGenerations(campaignId);
          if (this.campaignId !== campaignId) return;
          this.records = toClient(data.payload);
          this.schedulePoll();
        } catch {
          // History is best-effort; generation still works without it.
        }
      },

      async request(params) {
        this.isRequesting = true;
        try {
          const { data } = await GlintReachAPI.createGeneration(
            this.campaignId,
            toServer(params)
          );
          const generation = toClient(data);
          this.upsert(generation);
          this.schedulePoll();
          return generation;
        } catch (error) {
          return rethrowApiError(error);
        } finally {
          this.isRequesting = false;
        }
      },

      upsert(generation) {
        const index = this.records.findIndex(r => r.id === generation.id);
        if (index === -1) this.records.unshift(generation);
        else this.records.splice(index, 1, generation);
      },

      schedulePoll() {
        if (this.pollTimer || !this.active.length) return;
        this.pollTimer = setTimeout(() => {
          this.pollTimer = null;
          this.poll();
        }, POLL_INTERVAL_MS);
      },

      async poll() {
        const campaignId = this.campaignId;
        const settled = [];
        await Promise.all(
          this.active.map(async generation => {
            try {
              const { data } = await GlintReachAPI.getGeneration(generation.id);
              if (this.campaignId !== campaignId) return;
              const fresh = toClient(data);
              this.upsert(fresh);
              if (!isActiveGeneration(fresh)) settled.push(fresh);
            } catch {
              // Keep polling; a transient network error should not end tracking.
            }
          })
        );
        if (this.campaignId !== campaignId) return;
        if (settled.some(g => g.status === 'completed') && this.onSettled) {
          await this.onSettled(settled);
        }
        this.schedulePoll();
      },

      stopPolling() {
        if (this.pollTimer) clearTimeout(this.pollTimer);
        this.pollTimer = null;
      },

      reset() {
        this.stopPolling();
        this.$reset();
      },
    },
  }
);
