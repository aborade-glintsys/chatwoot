<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { debounce } from '@chatwoot/utils';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import { useGlintReachCampaignsStore } from 'dashboard/stores/glintReach/campaigns';
import GlintReachEmptyState from '../components/GlintReachEmptyState.vue';

const PER_PAGE = 25;
const STATUSES = ['draft', 'active', 'paused', 'completed', 'archived'];

const { t } = useI18n();
const router = useRouter();
const store = useGlintReachCampaignsStore();

const status = ref('');
const search = ref('');
const loadError = ref('');

const campaigns = computed(() => store.records);
const hasFilters = computed(() => Boolean(status.value || search.value));

const load = async (page = 1) => {
  loadError.value = '';
  try {
    await store.fetchCampaigns({
      page,
      status: status.value,
      search: search.value.trim(),
    });
  } catch (error) {
    loadError.value = error.message || t('GLINT_REACH.ERRORS.LOAD_FAILED');
  }
};

const onSearch = debounce(() => load(1), 300);

const clearFilters = () => {
  status.value = '';
  search.value = '';
  load(1);
};

const openCampaign = campaign =>
  router.push({
    name: 'glint_reach_content_studio_campaign',
    params: { campaignId: campaign.id },
  });

const newCampaign = () => router.push({ name: 'glint_reach_campaign_new' });

const formatDate = epoch =>
  epoch ? new Date(epoch * 1000).toLocaleDateString() : '';

onMounted(() => load(1));
</script>

<template>
  <section class="flex flex-col w-full max-w-5xl gap-6 px-6 py-10 mx-auto">
    <header class="flex flex-wrap items-end justify-between gap-4">
      <div class="flex flex-col gap-2">
        <span class="w-10 h-1 rounded-full bg-glint-reach" />
        <h1 class="mb-0 text-2xl font-semibold text-n-slate-12">
          {{ t('GLINT_REACH.MODULES.CAMPAIGNS.TITLE') }}
        </h1>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('GLINT_REACH.CAMPAIGNS.DESCRIPTION') }}
        </p>
      </div>
      <Button
        icon="i-lucide-plus"
        :label="t('GLINT_REACH.CAMPAIGNS.NEW')"
        data-testid="campaign-new"
        @click="newCampaign"
      />
    </header>

    <div class="flex flex-wrap items-center gap-3">
      <label class="sr-only" for="glint-reach-campaign-search">
        {{ t('GLINT_REACH.CAMPAIGNS.SEARCH') }}
      </label>
      <div class="relative flex-1 min-w-[12rem]">
        <span
          class="absolute -translate-y-1/2 i-lucide-search size-4 top-1/2 ltr:left-3 rtl:right-3 text-n-slate-10"
          aria-hidden="true"
        />
        <input
          id="glint-reach-campaign-search"
          v-model="search"
          type="search"
          autocomplete="off"
          spellcheck="false"
          :placeholder="t('GLINT_REACH.CAMPAIGNS.SEARCH')"
          class="block w-full h-10 ltr:pl-9 rtl:pr-9 px-3 text-sm rounded-lg reset-base !mb-0 outline outline-1 -outline-offset-1 outline-n-weak bg-n-alpha-black2 text-n-slate-12 placeholder:text-n-slate-10"
          @input="onSearch"
        />
      </div>
      <label class="sr-only" for="glint-reach-campaign-status">
        {{ t('GLINT_REACH.CAMPAIGNS.STATUS_FILTER') }}
      </label>
      <select
        id="glint-reach-campaign-status"
        v-model="status"
        class="h-10 px-3 text-sm rounded-lg outline outline-1 -outline-offset-1 outline-n-weak bg-n-surface-1 !mb-0 w-auto"
        @change="load(1)"
      >
        <option value="">{{ t('GLINT_REACH.CAMPAIGNS.ALL_ACTIVE') }}</option>
        <option v-for="value in STATUSES" :key="value" :value="value">
          {{ t(`GLINT_REACH.STATUSES.${value.toUpperCase()}`) }}
        </option>
      </select>
    </div>

    <div
      v-if="store.uiFlags.isFetching && !campaigns.length"
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
      <Button :label="t('GLINT_REACH.FORM.RETRY')" @click="load(1)" />
    </GlintReachEmptyState>

    <GlintReachEmptyState
      v-else-if="!campaigns.length && hasFilters"
      icon="i-lucide-search-x"
      :title="t('GLINT_REACH.CAMPAIGNS.NO_RESULTS_TITLE')"
      :description="t('GLINT_REACH.CAMPAIGNS.NO_RESULTS_DESCRIPTION')"
    >
      <Button
        variant="faded"
        :label="t('GLINT_REACH.CAMPAIGNS.CLEAR_FILTERS')"
        @click="clearFilters"
      />
    </GlintReachEmptyState>

    <GlintReachEmptyState
      v-else-if="!campaigns.length"
      icon="i-lucide-megaphone"
      :title="t('GLINT_REACH.CAMPAIGNS.EMPTY_TITLE')"
      :description="t('GLINT_REACH.CAMPAIGNS.EMPTY_DESCRIPTION')"
    >
      <Button
        icon="i-lucide-plus"
        :label="t('GLINT_REACH.CAMPAIGNS.NEW')"
        @click="newCampaign"
      />
    </GlintReachEmptyState>

    <template v-else>
      <ul class="flex flex-col gap-2" data-testid="campaign-list">
        <li v-for="campaign in campaigns" :key="campaign.id">
          <button
            type="button"
            class="flex flex-wrap items-center w-full gap-4 p-4 text-left transition-colors border rtl:text-right rounded-xl border-n-weak bg-n-solid-1 hover:border-glint-reach/50 hover:bg-n-alpha-1 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand group"
            @click="openCampaign(campaign)"
          >
            <div class="flex flex-col flex-1 min-w-0 gap-1">
              <span
                class="text-sm font-medium truncate text-n-slate-12 group-hover:text-glint-reach"
              >
                {{ campaign.name }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{
                  t(
                    `GLINT_REACH.OBJECTIVES.${campaign.objective.toUpperCase()}`
                  )
                }}
                <template v-if="campaign.startsAt">
                  · {{ formatDate(campaign.startsAt) }}
                  <template v-if="campaign.endsAt">
                    – {{ formatDate(campaign.endsAt) }}
                  </template>
                </template>
              </span>
            </div>
            <span
              class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11"
            >
              {{ t(`GLINT_REACH.STATUSES.${campaign.status.toUpperCase()}`) }}
            </span>
            <span
              class="i-lucide-chevron-right rtl:rotate-180 size-4 text-n-slate-10"
              aria-hidden="true"
            />
          </button>
        </li>
      </ul>
      <PaginationFooter
        v-if="store.meta.count > PER_PAGE"
        :current-page="store.meta.currentPage"
        :total-items="store.meta.count"
        :items-per-page="PER_PAGE"
        @update:current-page="load"
      />
    </template>
  </section>
</template>
