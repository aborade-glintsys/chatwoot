<script setup>
import { reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  useGlintReachGenerationsStore,
  isActiveGeneration,
} from 'dashboard/stores/glintReach/generations';
import { CHANNELS } from '../helpers/validation';
import VariantCard from './VariantCard.vue';
import GenerationStatus from './GenerationStatus.vue';

// A campaign's content items with their platform variants. When AI is enabled,
// each item can generate drafts for the chosen channels.
const props = defineProps({
  items: { type: Array, default: () => [] },
  campaignId: { type: Number, default: null },
  channels: { type: Array, default: () => [] },
  canEdit: { type: Boolean, default: false },
  aiEnabled: { type: Boolean, default: false },
});

const { t } = useI18n();
const generations = useGlintReachGenerationsStore();
// Per-item channel selection, defaulting to the brief's channels.
const selections = reactive({});
const selectionFor = item => selections[item.id] ?? props.channels;
const toggleChannel = (item, channel) => {
  const current = selectionFor(item);
  selections[item.id] = current.includes(channel)
    ? current.filter(c => c !== channel)
    : [...current, channel];
};
const latestVariants = item =>
  generations.latestFor({ kind: 'variants', contentItemId: item.id });

const generateVariants = async item => {
  const platforms = selectionFor(item);
  if (!platforms.length) {
    useAlert(t('GLINT_REACH.AI.PLATFORMS_REQUIRED'));
    return;
  }
  try {
    await generations.request({
      kind: 'variants',
      contentItemId: item.id,
      platforms,
    });
    useAlert(t('GLINT_REACH.AI.QUEUED_ALERT'));
  } catch (error) {
    useAlert(error.message || t('GLINT_REACH.AI.REQUEST_FAILED'));
  }
};
</script>

<template>
  <div
    v-if="!items.length"
    class="flex flex-col items-center gap-2 px-6 py-10 text-center border border-dashed rounded-xl border-n-weak"
    data-testid="content-items-empty"
  >
    <span class="i-lucide-files size-6 text-n-slate-10" aria-hidden="true" />
    <p class="mb-0 text-sm font-medium text-n-slate-12">
      {{ t('GLINT_REACH.CONTENT.EMPTY_TITLE') }}
    </p>
    <p class="max-w-md mb-0 text-sm text-n-slate-11">
      {{ t('GLINT_REACH.CONTENT.EMPTY_DESCRIPTION') }}
    </p>
  </div>
  <ul v-else class="flex flex-col gap-3" data-testid="content-items-list">
    <li
      v-for="item in items"
      :key="item.id"
      class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-1"
    >
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h3 class="mb-0 text-sm font-medium break-words text-n-slate-12">
          {{ item.title }}
        </h3>
        <div class="flex items-center gap-2 text-xs">
          <span class="px-2 py-0.5 rounded-full bg-n-alpha-2 text-n-slate-11">
            {{
              t(`GLINT_REACH.CONTENT_TYPES.${item.contentType.toUpperCase()}`)
            }}
          </span>
          <span class="px-2 py-0.5 rounded-full bg-n-alpha-2 text-n-slate-11">
            {{ t(`GLINT_REACH.STATUSES.${item.status.toUpperCase()}`) }}
          </span>
        </div>
      </div>
      <div
        v-if="aiEnabled && canEdit && item.status !== 'archived'"
        class="flex flex-col gap-2"
        data-testid="variant-generator"
      >
        <fieldset class="flex flex-wrap items-center gap-2 text-xs">
          <legend class="mb-1 text-xs text-n-slate-11">
            {{ t('GLINT_REACH.AI.PLATFORMS') }}
          </legend>
          <label
            v-for="channel in CHANNELS"
            :key="channel"
            class="inline-flex items-center gap-1 text-n-slate-12"
          >
            <input
              type="checkbox"
              class="!mb-0"
              :checked="selectionFor(item).includes(channel)"
              @change="toggleChannel(item, channel)"
            />
            {{ t(`GLINT_REACH.PLATFORMS.${channel.toUpperCase()}`) }}
          </label>
        </fieldset>
        <Button
          size="xs"
          variant="faded"
          icon="i-lucide-sparkles"
          class="w-fit"
          :label="t('GLINT_REACH.AI.GENERATE_VARIANTS')"
          :disabled="
            generations.isRequesting || isActiveGeneration(latestVariants(item))
          "
          @click="generateVariants(item)"
        />
        <GenerationStatus
          :generation="latestVariants(item)"
          @retry="generateVariants(item)"
        />
      </div>
      <p v-if="!item.variants.length" class="mb-0 text-xs text-n-slate-10">
        {{ t('GLINT_REACH.CONTENT.NO_VARIANTS') }}
      </p>
      <ul v-else class="grid gap-2">
        <VariantCard
          v-for="variant in item.variants"
          :key="variant.id"
          :variant="variant"
          :campaign-id="campaignId"
          :can-edit="canEdit"
          :ai-enabled="aiEnabled"
        />
      </ul>
    </li>
  </ul>
</template>
