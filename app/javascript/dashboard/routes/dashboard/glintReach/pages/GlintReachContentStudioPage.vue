<script setup>
import { ref, computed, watch, inject, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useGlintReachCampaignsStore } from 'dashboard/stores/glintReach/campaigns';
import { useGlintReachBrandProfileStore } from 'dashboard/stores/glintReach/brandProfile';
import { useGlintReachGenerationsStore } from 'dashboard/stores/glintReach/generations';
import { useGlintReachSocialAccountsStore } from 'dashboard/stores/glintReach/socialAccounts';
import AiGenerationPanel from '../components/AiGenerationPanel.vue';
import AssetsPanel from '../components/AssetsPanel.vue';
import CampaignBriefForm from '../components/CampaignBriefForm.vue';
import ContentItemsList from '../components/ContentItemsList.vue';
import GlintReachEmptyState from '../components/GlintReachEmptyState.vue';
import { LOCKED_STATUSES } from '../helpers/validation';

// Three modes: pick a campaign (no id), create a campaign ('new'), or work on
// one campaign's brief and content (campaignId).
const props = defineProps({
  campaignId: { type: [String, Number], default: null },
  isNew: { type: Boolean, default: false },
});

const { t } = useI18n();
const router = useRouter();
const campaignsStore = useGlintReachCampaignsStore();
const brandStore = useGlintReachBrandProfileStore();
const generationsStore = useGlintReachGenerationsStore();
const socialStore = useGlintReachSocialAccountsStore();
const shell = inject('glintReachShell', ref(null));
const aiConfigured = computed(() => Boolean(shell.value?.ai_configured));

const loadError = ref('');
const serverMessage = ref('');
const serverErrorFields = ref([]);
// Re-mounts the form with fresh values after a save or campaign switch.
const formKey = ref(0);

const campaign = computed(() =>
  props.campaignId ? campaignsStore.current : null
);
const isLocked = computed(() =>
  LOCKED_STATUSES.includes(campaign.value?.status)
);
const aiEnabled = computed(() => aiConfigured.value && !isLocked.value);
const mode = computed(() => {
  if (props.isNew) return 'new';
  if (props.campaignId) return 'campaign';
  return 'picker';
});

const resetServerErrors = () => {
  serverMessage.value = '';
  serverErrorFields.value = [];
};

const load = async () => {
  loadError.value = '';
  resetServerErrors();
  // The brand profile hint is best-effort; it never blocks the studio.
  if (!brandStore.hasLoaded) brandStore.fetch().catch(() => {});
  if (!socialStore.hasLoaded) socialStore.fetchAll().catch(() => {});
  generationsStore.reset();
  try {
    if (mode.value === 'campaign') {
      await campaignsStore.fetchCampaign(props.campaignId);
      formKey.value += 1;
      // Generated content is written server-side; reload the campaign when a
      // generation completes so the new strategy/items/variants appear.
      generationsStore.load(campaignsStore.current.id, () =>
        campaignsStore.refreshCurrent()
      );
    } else if (mode.value === 'picker') {
      await campaignsStore.fetchCampaigns({ page: 1, status: '', search: '' });
    }
  } catch (error) {
    loadError.value = error.message || t('GLINT_REACH.ERRORS.LOAD_FAILED');
  }
};

const onSubmit = async attributes => {
  resetServerErrors();
  try {
    if (mode.value === 'new') {
      const created = await campaignsStore.createCampaign(attributes);
      useAlert(t('GLINT_REACH.BRIEF.CREATED'));
      router.replace({
        name: 'glint_reach_content_studio_campaign',
        params: { campaignId: created.id },
      });
    } else {
      await campaignsStore.updateCampaign(campaign.value.id, attributes);
      formKey.value += 1;
      useAlert(t('GLINT_REACH.BRIEF.SAVED'));
    }
  } catch (error) {
    serverMessage.value = error.message || t('GLINT_REACH.ERRORS.SAVE_FAILED');
    serverErrorFields.value = error.attributes || [];
  }
};

const openCampaign = id =>
  router.push({
    name: 'glint_reach_content_studio_campaign',
    params: { campaignId: id },
  });

watch(() => [props.campaignId, props.isNew], load, { immediate: true });
onBeforeUnmount(() => generationsStore.reset());
</script>

<template>
  <section class="flex flex-col w-full max-w-5xl gap-6 px-6 py-10 mx-auto">
    <header class="flex flex-col gap-2">
      <router-link
        v-if="mode !== 'picker'"
        :to="{ name: 'glint_reach_campaigns' }"
        class="inline-flex items-center gap-1 text-sm w-fit text-n-slate-11 hover:text-n-slate-12"
      >
        <span
          class="i-lucide-arrow-left rtl:rotate-180 size-4"
          aria-hidden="true"
        />
        {{ t('GLINT_REACH.CONTENT_STUDIO.BACK') }}
      </router-link>
      <span class="w-10 h-1 rounded-full bg-glint-reach" />
      <h1 class="mb-0 text-2xl font-semibold break-words text-n-slate-12">
        <template v-if="mode === 'new'">
          {{ t('GLINT_REACH.CAMPAIGNS.NEW') }}
        </template>
        <template v-else-if="mode === 'campaign' && campaign">
          {{ campaign.name }}
        </template>
        <template v-else>
          {{ t('GLINT_REACH.MODULES.CONTENT_STUDIO.TITLE') }}
        </template>
      </h1>
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('GLINT_REACH.CONTENT_STUDIO.DESCRIPTION') }}
      </p>
    </header>

    <div
      v-if="
        campaignsStore.uiFlags.isFetchingItem ||
        (mode === 'picker' &&
          campaignsStore.uiFlags.isFetching &&
          !campaignsStore.records.length)
      "
      class="flex justify-center py-16"
    >
      <Spinner />
    </div>

    <GlintReachEmptyState
      v-else-if="loadError"
      icon="i-lucide-triangle-alert"
      :title="t('GLINT_REACH.ERRORS.LOAD_FAILED')"
      :description="loadError"
    >
      <Button :label="t('GLINT_REACH.FORM.RETRY')" @click="load" />
    </GlintReachEmptyState>

    <!-- Picker -->
    <template v-else-if="mode === 'picker'">
      <GlintReachEmptyState
        v-if="!campaignsStore.records.length"
        icon="i-lucide-pen-tool"
        :title="t('GLINT_REACH.CONTENT_STUDIO.EMPTY_TITLE')"
        :description="t('GLINT_REACH.CONTENT_STUDIO.EMPTY_DESCRIPTION')"
      >
        <Button
          icon="i-lucide-plus"
          :label="t('GLINT_REACH.CAMPAIGNS.NEW')"
          @click="router.push({ name: 'glint_reach_campaign_new' })"
        />
      </GlintReachEmptyState>
      <div v-else class="flex flex-col gap-3">
        <h2 class="mb-0 text-base font-medium text-n-slate-12">
          {{ t('GLINT_REACH.CONTENT_STUDIO.PICK_CAMPAIGN') }}
        </h2>
        <ul
          class="grid gap-3 sm:grid-cols-2"
          data-testid="studio-campaign-picker"
        >
          <li v-for="item in campaignsStore.records" :key="item.id">
            <button
              type="button"
              class="flex flex-col w-full h-full gap-1 p-4 text-left transition-colors border rtl:text-right rounded-xl border-n-weak bg-n-solid-1 hover:border-glint-reach/50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
              @click="openCampaign(item.id)"
            >
              <span class="text-sm font-medium truncate text-n-slate-12">
                {{ item.name }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{ t(`GLINT_REACH.STATUSES.${item.status.toUpperCase()}`) }}
              </span>
            </button>
          </li>
        </ul>
      </div>
    </template>

    <!-- New campaign / campaign workspace -->
    <div
      v-else-if="mode === 'new' || campaign"
      class="grid gap-6 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]"
    >
      <article
        class="flex flex-col gap-5 p-6 border rounded-2xl border-n-weak bg-n-solid-1"
      >
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h2 class="mb-0 text-base font-medium text-n-slate-12">
            {{ t('GLINT_REACH.BRIEF.TITLE') }}
          </h2>
          <span
            v-if="campaign"
            class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11"
          >
            {{ t(`GLINT_REACH.STATUSES.${campaign.status.toUpperCase()}`) }}
          </span>
        </div>
        <p
          v-if="isLocked"
          class="px-4 py-3 mb-0 text-sm rounded-lg bg-n-amber-3 text-n-amber-11"
          data-testid="brief-locked"
        >
          {{ t('GLINT_REACH.BRIEF.LOCKED') }}
        </p>
        <CampaignBriefForm
          :key="formKey"
          :campaign="campaign"
          :readonly="isLocked"
          :is-saving="campaignsStore.uiFlags.isSaving"
          :server-message="serverMessage"
          :server-error-fields="serverErrorFields"
          @submit="onSubmit"
        />
      </article>

      <aside class="flex flex-col gap-6">
        <div
          v-if="brandStore.hasLoaded && !brandStore.profile"
          class="flex flex-col gap-3 p-4 border rounded-xl border-glint-reach/30 bg-glint-reach/5"
          data-testid="brand-profile-hint"
        >
          <p class="mb-0 text-sm font-medium text-n-slate-12">
            {{ t('GLINT_REACH.CONTENT_STUDIO.BRAND_HINT_TITLE') }}
          </p>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('GLINT_REACH.CONTENT_STUDIO.BRAND_HINT_DESCRIPTION') }}
          </p>
          <router-link
            :to="{ name: 'glint_reach_brand_profile' }"
            class="text-sm font-medium text-glint-reach hover:underline w-fit"
          >
            {{ t('GLINT_REACH.BRAND_PROFILE.CREATE') }}
          </router-link>
        </div>

        <div
          v-if="campaign && !aiConfigured"
          class="flex flex-col gap-1 p-4 border rounded-xl border-n-amber-6 bg-n-amber-3"
          data-testid="ai-not-configured"
        >
          <p class="mb-0 text-sm font-medium text-n-amber-12">
            {{ t('GLINT_REACH.AI.NOT_CONFIGURED_TITLE') }}
          </p>
          <p class="mb-0 text-sm text-n-amber-11">
            {{ t('GLINT_REACH.AI.NOT_CONFIGURED_DESCRIPTION') }}
          </p>
        </div>
        <p
          v-else-if="campaign && isLocked"
          class="px-4 py-3 mb-0 text-sm rounded-lg bg-n-alpha-2 text-n-slate-11"
        >
          {{ t('GLINT_REACH.AI.LOCKED') }}
        </p>
        <template v-if="campaign && aiEnabled">
          <p class="mb-0 text-xs text-n-slate-10">
            {{ t('GLINT_REACH.AI.SAVE_BRIEF_FIRST') }}
          </p>
          <AiGenerationPanel :campaign="campaign" :enabled="aiEnabled" />
        </template>

        <AssetsPanel
          v-if="campaign"
          :campaign-id="campaign.id"
          :can-edit="!isLocked"
          @changed="campaignsStore.refreshCurrent()"
        />

        <section v-if="campaign" class="flex flex-col gap-3">
          <h2 class="mb-0 text-base font-medium text-n-slate-12">
            {{ t('GLINT_REACH.CONTENT.TITLE') }}
          </h2>
          <ContentItemsList
            :items="campaign.contentItems || []"
            :campaign-id="campaign.id"
            :channels="campaign.channels || []"
            :can-edit="!isLocked"
            :ai-enabled="aiEnabled"
          />
        </section>
      </aside>
    </div>
  </section>
</template>
