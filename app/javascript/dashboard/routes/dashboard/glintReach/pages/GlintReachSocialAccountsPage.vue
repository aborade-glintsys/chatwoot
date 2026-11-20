<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useGlintReachSocialAccountsStore } from 'dashboard/stores/glintReach/socialAccounts';
import { daysUntilExpiry } from '../helpers/capabilities';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useGlintReachSocialAccountsStore();

const loadError = ref('');
const actionError = ref('');
const callbackBanner = ref(null);
const pendingDisconnect = ref(null);
const disconnectDialog = ref(null);

const STATUS_CLASSES = {
  connected: 'bg-n-teal-3 text-n-teal-11',
  expired: 'bg-n-amber-3 text-n-amber-11',
  missing_scopes: 'bg-n-amber-3 text-n-amber-11',
  revoked: 'bg-n-alpha-2 text-n-slate-11',
  error: 'bg-n-ruby-3 text-n-ruby-11',
};

const readCallbackBanner = () => {
  const outcome = route.query.oauth;
  if (!outcome) return;
  const code = route.query.code || '';
  if (outcome === 'connected') {
    callbackBanner.value = {
      tone: 'success',
      text: t('GLINT_REACH.SOCIAL.CALLBACK.CONNECTED'),
    };
  } else if (outcome === 'missing_scopes') {
    callbackBanner.value = {
      tone: 'warning',
      text: t('GLINT_REACH.SOCIAL.CALLBACK.MISSING_SCOPES'),
    };
  } else {
    const key =
      code === 'access_denied'
        ? 'GLINT_REACH.SOCIAL.CALLBACK.ACCESS_DENIED'
        : 'GLINT_REACH.SOCIAL.CALLBACK.ERROR';
    callbackBanner.value = { tone: 'error', text: t(key) };
  }
  const rest = { ...route.query };
  delete rest.oauth;
  delete rest.code;
  router.replace({ query: rest });
};

const load = async () => {
  loadError.value = '';
  try {
    await store.fetchAll();
  } catch (error) {
    loadError.value = error.message || t('GLINT_REACH.ERRORS.LOAD_FAILED');
  }
};

const connect = async providerKey => {
  actionError.value = '';
  try {
    const url = await store.startAuthorize(providerKey);
    window.location.assign(url);
  } catch (error) {
    actionError.value = error.message || t('GLINT_REACH.SOCIAL.CONNECT_FAILED');
  }
};

const askDisconnect = account => {
  pendingDisconnect.value = account;
  disconnectDialog.value?.open();
};

const confirmDisconnect = async () => {
  const account = pendingDisconnect.value;
  disconnectDialog.value?.close();
  pendingDisconnect.value = null;
  if (!account) return;
  actionError.value = '';
  try {
    await store.disconnect(account.id);
    useAlert(t('GLINT_REACH.SOCIAL.DISCONNECTED'));
  } catch (error) {
    actionError.value =
      error.message || t('GLINT_REACH.SOCIAL.DISCONNECT_FAILED');
  }
};

const statusLabel = account => {
  if (account.status === 'connected' && account.tokenExpiresAt) {
    const days = daysUntilExpiry(account.tokenExpiresAt);
    if (days !== null && days <= 14) {
      return t('GLINT_REACH.SOCIAL.STATUS.EXPIRES_IN', { days });
    }
  }
  return t(`GLINT_REACH.SOCIAL.STATUS.${account.status.toUpperCase()}`);
};

const canReconnect = account =>
  Boolean(store.providerByKey(account.provider)?.connectable);

onMounted(() => {
  readCallbackBanner();
  load();
});
</script>

<template>
  <section class="flex flex-col w-full max-w-5xl gap-6 px-6 py-10 mx-auto">
    <header class="flex flex-col gap-2">
      <span class="w-10 h-1 rounded-full bg-glint-reach" />
      <h1 class="mb-0 text-2xl font-semibold text-n-slate-12">
        {{ t('GLINT_REACH.MODULES.SOCIAL_ACCOUNTS.TITLE') }}
      </h1>
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('GLINT_REACH.SOCIAL.DESCRIPTION') }}
      </p>
    </header>

    <p
      v-if="callbackBanner"
      class="px-4 py-3 mb-0 text-sm rounded-xl"
      :class="
        callbackBanner.tone === 'success'
          ? 'bg-n-teal-3 text-n-teal-11'
          : callbackBanner.tone === 'warning'
            ? 'bg-n-amber-3 text-n-amber-11'
            : 'bg-n-ruby-3 text-n-ruby-11'
      "
      role="status"
      data-testid="social-callback-banner"
    >
      {{ callbackBanner.text }}
    </p>

    <p
      v-if="actionError"
      class="px-4 py-3 mb-0 text-sm rounded-xl bg-n-ruby-3 text-n-ruby-11"
      role="alert"
      data-testid="social-action-error"
    >
      {{ actionError }}
    </p>

    <div
      v-if="store.uiFlags.isFetching && !store.hasLoaded"
      class="flex justify-center py-12"
    >
      <Spinner />
    </div>
    <div
      v-else-if="loadError"
      class="flex items-center gap-2 text-sm text-n-ruby-11"
      role="alert"
    >
      {{ loadError }}
      <Button
        size="xs"
        variant="ghost"
        :label="t('GLINT_REACH.FORM.RETRY')"
        @click="load"
      />
    </div>
    <template v-else>
      <section class="flex flex-col gap-3" data-testid="social-providers">
        <h2 class="mb-0 text-base font-medium text-n-slate-12">
          {{ t('GLINT_REACH.SOCIAL.PROVIDERS_TITLE') }}
        </h2>
        <ul class="grid gap-4 sm:grid-cols-2">
          <li
            v-for="provider in store.providers"
            :key="provider.key"
            class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-1"
            :data-testid="`provider-card-${provider.key}`"
          >
            <div class="flex items-center justify-between gap-2">
              <span class="text-base font-medium text-n-slate-12">
                {{ provider.displayName }}
              </span>
              <span
                class="px-2 py-0.5 text-xs rounded-full"
                :class="
                  provider.connectable
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-amber-3 text-n-amber-11'
                "
              >
                {{
                  provider.connectable
                    ? t('GLINT_REACH.SOCIAL.READY')
                    : t('GLINT_REACH.SOCIAL.SETUP_REQUIRED')
                }}
              </span>
            </div>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ provider.approvalNotes }}
            </p>
            <dl class="grid grid-cols-2 gap-2 text-xs text-n-slate-11">
              <div>
                <dt class="font-medium text-n-slate-12">
                  {{ t('GLINT_REACH.SOCIAL.CAPABILITIES.POST_TYPES') }}
                </dt>
                <dd class="m-0">
                  {{ provider.capabilities.postTypes.join(', ') }}
                </dd>
              </div>
              <div>
                <dt class="font-medium text-n-slate-12">
                  {{ t('GLINT_REACH.SOCIAL.CAPABILITIES.TEXT_LIMIT') }}
                </dt>
                <dd class="m-0">
                  {{
                    t('GLINT_REACH.SOCIAL.CAPABILITIES.CHARS', {
                      count: provider.capabilities.maxTextLength,
                    })
                  }}
                </dd>
              </div>
              <div>
                <dt class="font-medium text-n-slate-12">
                  {{ t('GLINT_REACH.SOCIAL.CAPABILITIES.IMAGES') }}
                </dt>
                <dd class="m-0">
                  {{
                    t('GLINT_REACH.SOCIAL.CAPABILITIES.MAX_IMAGES', {
                      count: provider.capabilities.maxImages,
                    })
                  }}
                </dd>
              </div>
              <div>
                <dt class="font-medium text-n-slate-12">
                  {{ t('GLINT_REACH.SOCIAL.CAPABILITIES.TOKEN_LIFETIME') }}
                </dt>
                <dd class="m-0">
                  {{
                    t('GLINT_REACH.SOCIAL.CAPABILITIES.DAYS', {
                      days: provider.capabilities.tokenLifetimeDays,
                    })
                  }}
                </dd>
              </div>
            </dl>
            <p
              v-if="!provider.encryptionConfigured"
              class="px-3 py-2 mb-0 text-xs rounded-lg bg-n-amber-3 text-n-amber-11"
              data-testid="provider-encryption-warning"
            >
              {{ t('GLINT_REACH.SOCIAL.ENCRYPTION_MISSING') }}
            </p>
            <p
              v-else-if="!provider.configured"
              class="px-3 py-2 mb-0 text-xs rounded-lg bg-n-amber-3 text-n-amber-11"
              data-testid="provider-credentials-warning"
            >
              {{ t('GLINT_REACH.SOCIAL.CREDENTIALS_MISSING') }}
            </p>
            <Button
              size="sm"
              icon="i-lucide-link"
              class="w-fit"
              :data-testid="`connect-${provider.key}`"
              :label="
                t('GLINT_REACH.SOCIAL.CONNECT', { name: provider.displayName })
              "
              :disabled="!provider.connectable || store.uiFlags.isAuthorizing"
              :is-loading="store.uiFlags.isAuthorizing"
              @click="connect(provider.key)"
            />
          </li>
        </ul>
      </section>

      <section class="flex flex-col gap-3" data-testid="connected-accounts">
        <h2 class="mb-0 text-base font-medium text-n-slate-12">
          {{ t('GLINT_REACH.SOCIAL.ACCOUNTS_TITLE') }}
        </h2>
        <p
          v-if="!store.accounts.length"
          class="px-4 py-8 mb-0 text-sm text-center border border-dashed rounded-xl border-n-weak text-n-slate-11"
          data-testid="social-accounts-empty"
        >
          {{ t('GLINT_REACH.SOCIAL.EMPTY') }}
        </p>
        <ul v-else class="flex flex-col gap-3">
          <li
            v-for="account in store.accounts"
            :key="account.id"
            class="flex flex-col gap-2 p-4 border rounded-xl border-n-weak bg-n-solid-1"
            :data-testid="`social-account-${account.id}`"
          >
            <div class="flex flex-wrap items-center justify-between gap-2">
              <div class="flex flex-col">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ account.displayName }}
                </span>
                <span class="text-xs text-n-slate-11">
                  {{
                    t('GLINT_REACH.SOCIAL.ACCOUNT_META', {
                      provider: t(
                        `GLINT_REACH.PLATFORMS.${account.provider.toUpperCase()}`
                      ),
                      type: account.providerAccountType,
                    })
                  }}
                </span>
              </div>
              <span
                class="px-2 py-0.5 text-xs rounded-full"
                :class="
                  STATUS_CLASSES[account.status] ||
                  'bg-n-alpha-2 text-n-slate-11'
                "
                :data-testid="`social-status-${account.id}`"
              >
                {{ statusLabel(account) }}
              </span>
            </div>
            <p
              v-if="account.grantedScopes?.length"
              class="mb-0 text-xs text-n-slate-11"
            >
              {{
                t('GLINT_REACH.SOCIAL.SCOPES', {
                  scopes: account.grantedScopes.join(', '),
                })
              }}
            </p>
            <p
              v-if="account.lastErrorMessage"
              class="px-3 py-2 mb-0 text-xs rounded-lg bg-n-amber-3 text-n-amber-11"
            >
              {{ account.lastErrorMessage }}
            </p>
            <div class="flex flex-wrap gap-2">
              <Button
                v-if="account.status !== 'connected' && canReconnect(account)"
                size="xs"
                variant="faded"
                icon="i-lucide-refresh-cw"
                :data-testid="`reconnect-${account.id}`"
                :label="t('GLINT_REACH.SOCIAL.RECONNECT')"
                :disabled="store.uiFlags.isAuthorizing"
                @click="connect(account.provider)"
              />
              <Button
                v-if="account.status !== 'revoked'"
                size="xs"
                variant="ghost"
                color="ruby"
                icon="i-lucide-unlink"
                :data-testid="`disconnect-${account.id}`"
                :label="t('GLINT_REACH.SOCIAL.DISCONNECT')"
                :is-loading="store.uiFlags.disconnectingId === account.id"
                @click="askDisconnect(account)"
              />
            </div>
          </li>
        </ul>
      </section>
    </template>

    <Dialog
      ref="disconnectDialog"
      type="alert"
      :title="t('GLINT_REACH.SOCIAL.DISCONNECT_TITLE')"
      :description="t('GLINT_REACH.SOCIAL.DISCONNECT_DESCRIPTION')"
      :confirm-button-label="t('GLINT_REACH.SOCIAL.DISCONNECT')"
      @confirm="confirmDisconnect"
    />
  </section>
</template>
