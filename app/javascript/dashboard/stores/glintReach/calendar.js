import { defineStore } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import { toClient, rethrowApiError } from './helpers';

// Calendar/list feed and the approval queue. Requests carry a token so a
// slower, older response never overwrites a newer one.
export const useGlintReachCalendarStore = defineStore('glintReachCalendar', {
  state: () => ({
    items: [],
    approvals: [],
    approvalsCount: 0,
    uiFlags: { isFetching: false, isFetchingApprovals: false },
    token: 0,
  }),

  actions: {
    async fetchCalendar(params) {
      this.token += 1;
      const token = this.token;
      this.uiFlags.isFetching = true;
      try {
        const { data } = await GlintReachAPI.getCalendar(params);
        if (token !== this.token) return this.items;
        this.items = toClient(data.payload);
        return this.items;
      } catch (error) {
        if (token === this.token) this.items = [];
        return rethrowApiError(error);
      } finally {
        if (token === this.token) this.uiFlags.isFetching = false;
      }
    },

    async fetchApprovals(page = 1) {
      this.uiFlags.isFetchingApprovals = true;
      try {
        const { data } = await GlintReachAPI.getApprovals({ page });
        this.approvals = toClient(data.payload);
        this.approvalsCount = data.meta.count;
        return this.approvals;
      } catch (error) {
        return rethrowApiError(error);
      } finally {
        this.uiFlags.isFetchingApprovals = false;
      }
    },

    // Runs a workflow action from the queue and drops the item once decided.
    async runQueueWorkflow(target, action, params) {
      try {
        const { data } = await GlintReachAPI.variantWorkflow(
          target,
          action,
          params
        );
        const variant = toClient(data);
        if (variant.status !== 'in_review') {
          this.approvals = this.approvals.filter(
            item => item.id !== variant.id
          );
          this.approvalsCount = Math.max(0, this.approvalsCount - 1);
        }
        return variant;
      } catch (error) {
        return rethrowApiError(error);
      }
    },

    reset() {
      this.$reset();
    },
  },
});
