<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useGlintReachCalendarStore } from 'dashboard/stores/glintReach/calendar';
import WorkflowPanel from './WorkflowPanel.vue';

// Variants waiting for review, oldest first, with inline approve / request changes.
const { t } = useI18n();
const store = useGlintReachCalendarStore();
const loadError = ref('');

const load = async () => {
  loadError.value = '';
  try {
    await store.fetchApprovals();
  } catch (error) {
    loadError.value = error.message || t('GLINT_REACH.ERRORS.LOAD_FAILED');
  }
};

onMounted(load);
</script>

<template>
  <section class="flex flex-col gap-3" data-testid="approval-queue">
    <div
      v-if="store.uiFlags.isFetchingApprovals && !store.approvals.length"
      class="flex justify-center py-10"
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
    <p
      v-else-if="!store.approvals.length"
      class="px-4 py-8 mb-0 text-sm text-center border border-dashed rounded-xl border-n-weak text-n-slate-11"
      data-testid="approval-queue-empty"
    >
      {{ t('GLINT_REACH.APPROVALS.EMPTY') }}
    </p>
    <ul v-else class="flex flex-col gap-3">
      <li
        v-for="variant in store.approvals"
        :key="variant.id"
        class="flex flex-col gap-2 p-4 border rounded-xl border-n-weak bg-n-solid-1"
        :data-testid="`approval-${variant.id}`"
      >
        <div
          class="flex flex-wrap items-center justify-between gap-2 text-xs text-n-slate-11"
        >
          <span class="font-medium text-n-slate-12">
            {{ variant.contentItem.title }}
          </span>
          <span>
            {{
              t('GLINT_REACH.APPROVALS.META', {
                campaign: variant.campaign.name,
                platform: t(
                  `GLINT_REACH.PLATFORMS.${variant.platform.toUpperCase()}`
                ),
                name: variant.submittedBy?.name || '',
              })
            }}
          </span>
        </div>
        <p class="mb-0 text-sm whitespace-pre-line break-words text-n-slate-12">
          {{ variant.body }}
        </p>
        <p v-if="variant.callToAction" class="mb-0 text-xs text-n-slate-11">
          {{ variant.callToAction }}
        </p>
        <p
          v-if="variant.hashtags.length"
          class="mb-0 text-xs break-words text-n-slate-11"
        >
          {{ variant.hashtags.map(tag => `#${tag}`).join(' ') }}
        </p>
        <ul v-if="variant.assets?.length" class="flex flex-wrap gap-1">
          <li
            v-for="asset in variant.assets"
            :key="asset.id"
            class="overflow-hidden rounded size-16 bg-n-alpha-2"
          >
            <img
              :src="asset.thumbnailUrl"
              :alt="asset.altText || ''"
              loading="lazy"
              class="object-cover w-full h-full"
            />
          </li>
        </ul>
        <WorkflowPanel
          :variant="variant"
          :campaign-id="variant.campaign.id"
          :runner="store.runQueueWorkflow"
        />
      </li>
    </ul>
  </section>
</template>
