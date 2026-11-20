import { defineStore } from 'pinia';
import GlintReachAPI from 'dashboard/api/glintReach';
import { toClient, rethrowApiError } from './helpers';

export const useGlintReachSocialAccountsStore = defineStore(
  'glintReachSocialAccounts',
  {
    state: () => ({
      providers: [],
      accounts: [],
      hasLoaded: false,
      uiFlags: {
        isFetching: false,
        isAuthorizing: false,
        disconnectingId: null,
      },
    }),

    getters: {
      providerByKey: state => key =>
        state.providers.find(provider => provider.key === key) || null,
      connectedForProvider: state => key =>
        state.accounts.filter(
          account => account.provider === key && account.status === 'connected'
        ),
    },

    actions: {
      async fetchAll() {
        this.uiFlags.isFetching = true;
        try {
          const [providersRes, accountsRes] = await Promise.all([
            GlintReachAPI.getSocialProviders(),
            GlintReachAPI.getSocialAccounts(),
          ]);
          this.providers = toClient(providersRes.data.payload);
          this.accounts = toClient(accountsRes.data.payload);
          this.hasLoaded = true;
          return { providers: this.providers, accounts: this.accounts };
        } catch (error) {
          return rethrowApiError(error);
        } finally {
          this.uiFlags.isFetching = false;
        }
      },

      async startAuthorize(provider) {
        this.uiFlags.isAuthorizing = true;
        try {
          const { data } = await GlintReachAPI.authorizeSocialAccount(provider);
          return data.url;
        } catch (error) {
          return rethrowApiError(error);
        } finally {
          this.uiFlags.isAuthorizing = false;
        }
      },

      async disconnect(id) {
        this.uiFlags.disconnectingId = id;
        try {
          const { data } = await GlintReachAPI.disconnectSocialAccount(id);
          const updated = toClient(data);
          const index = this.accounts.findIndex(account => account.id === id);
          if (index !== -1) this.accounts.splice(index, 1, updated);
          return updated;
        } catch (error) {
          return rethrowApiError(error);
        } finally {
          this.uiFlags.disconnectingId = null;
        }
      },

      reset() {
        this.$reset();
      },
    },
  }
);
