<script setup>
import { ref, computed, watch, provide } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import GlintReachAPI from 'dashboard/api/glintReach';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';

// The dashboard router only enforces `meta.permissions`, so the feature flag is
// gated here and re-verified by the server before any child page renders.
const { t } = useI18n();
const route = useRoute();
const { isFeatureFlagEnabled } = usePolicy();

const shell = ref(null);
const isLoading = ref(false);
const isDenied = ref(false);

const isEnabled = computed(() =>
  isFeatureFlagEnabled(FEATURE_FLAGS.GLINT_REACH)
);

provide('glintReachShell', shell);

const fetchShell = async () => {
  shell.value = null;
  isDenied.value = false;
  if (!isEnabled.value) return;

  isLoading.value = true;
  try {
    const { data } = await GlintReachAPI.getShell();
    shell.value = data;
  } catch {
    isDenied.value = true;
  } finally {
    isLoading.value = false;
  }
};

watch([isEnabled, () => route.params.accountId], fetchShell, {
  immediate: true,
});
</script>

<template>
  <div class="flex flex-col flex-1 h-full m-0 overflow-auto bg-n-surface-1">
    <EmptyStateLayout
      v-if="!isEnabled || isDenied"
      :title="t('GLINT_REACH.DISABLED.TITLE')"
      :subtitle="t('GLINT_REACH.DISABLED.DESCRIPTION')"
      :show-backdrop="false"
    />
    <div
      v-else-if="isLoading || !shell"
      class="flex items-center justify-center flex-1"
    >
      <Spinner />
    </div>
    <router-view v-else />
  </div>
</template>
