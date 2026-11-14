<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

// Shows the latest generation state for one target, with the server's
// actionable error message and a Retry button on failure.
const props = defineProps({
  generation: { type: Object, default: null },
  canRetry: { type: Boolean, default: true },
});
const emit = defineEmits(['retry']);
const { t } = useI18n();

const isActive = computed(() =>
  ['queued', 'generating'].includes(props.generation?.status)
);
const skipped = computed(
  () => props.generation?.result?.skippedPlatforms || []
);
</script>

<template>
  <div
    v-if="generation && generation.status !== 'completed'"
    class="flex flex-col gap-2 text-xs"
    :data-testid="`generation-status-${generation.status}`"
    role="status"
    aria-live="polite"
  >
    <span
      v-if="isActive"
      class="inline-flex items-center gap-1.5 text-n-slate-11"
    >
      <span class="i-lucide-loader-circle size-3.5 animate-spin" />
      {{ t(`GLINT_REACH.AI.STATUS.${generation.status.toUpperCase()}`) }}
    </span>
    <div
      v-else-if="generation.status === 'failed'"
      class="flex flex-wrap items-center gap-2 px-3 py-2 rounded-lg bg-n-ruby-3 text-n-ruby-11"
    >
      <span class="flex-1 break-words">{{ generation.errorMessage }}</span>
      <Button
        v-if="canRetry"
        size="xs"
        color="ruby"
        variant="faded"
        :label="t('GLINT_REACH.AI.RETRY')"
        @click="emit('retry')"
      />
    </div>
  </div>
  <p
    v-else-if="generation && skipped.length"
    class="mb-0 text-xs text-n-slate-11"
    data-testid="generation-skipped"
  >
    {{
      t('GLINT_REACH.AI.SKIPPED_READY', {
        platforms: skipped
          .map(p => t(`GLINT_REACH.PLATFORMS.${p.toUpperCase()}`))
          .join(', '),
      })
    }}
  </p>
</template>
