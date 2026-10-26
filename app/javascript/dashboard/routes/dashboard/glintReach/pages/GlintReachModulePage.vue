<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import { GLINT_REACH_MODULES } from '../constants';

const props = defineProps({
  moduleKey: {
    type: String,
    required: true,
  },
});

const { t } = useI18n();

const module = computed(() =>
  GLINT_REACH_MODULES.find(({ key }) => key === props.moduleKey)
);
</script>

<template>
  <EmptyStateLayout
    :title="t(`GLINT_REACH.MODULES.${module.i18nKey}.TITLE`)"
    :subtitle="t('GLINT_REACH.UNAVAILABLE.DESCRIPTION')"
    :show-backdrop="false"
  >
    <template #actions>
      <span
        class="px-3 py-1 text-sm font-medium rounded-full bg-n-alpha-2 text-n-slate-11"
      >
        {{ t('GLINT_REACH.UNAVAILABLE.BADGE') }}
      </span>
    </template>
  </EmptyStateLayout>
</template>
