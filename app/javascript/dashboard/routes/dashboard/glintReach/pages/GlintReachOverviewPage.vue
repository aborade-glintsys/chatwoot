<script setup>
import { computed, inject } from 'vue';
import { useI18n } from 'vue-i18n';
import { GLINT_REACH_MODULES } from '../constants';

const { t } = useI18n();
const shell = inject('glintReachShell');

// Overview is the current page; list the other modules with their server-reported status.
const modules = computed(() =>
  GLINT_REACH_MODULES.filter(({ key }) => key !== 'overview').map(module => ({
    ...module,
    available:
      shell.value?.modules?.find(({ key }) => key === module.key)?.available ===
      true,
  }))
);
</script>

<template>
  <section class="flex flex-col w-full max-w-5xl gap-8 px-6 py-10 mx-auto">
    <header class="flex flex-col gap-2">
      <span class="w-10 h-1 rounded-full bg-glint-reach" />
      <h1 class="text-2xl font-semibold text-n-slate-12">
        {{ t('GLINT_REACH.PRODUCT_NAME') }}
      </h1>
      <p class="text-base text-n-slate-11">{{ t('GLINT_REACH.TAGLINE') }}</p>
      <p class="text-sm text-n-slate-10">
        {{ t('GLINT_REACH.OVERVIEW.DESCRIPTION') }}
      </p>
    </header>

    <ul class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <li
        v-for="module in modules"
        :key="module.key"
        class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-1"
      >
        <div class="flex items-center justify-between">
          <span class="size-5 text-n-slate-11" :class="module.icon" />
          <span
            class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11"
          >
            {{
              module.available
                ? t('GLINT_REACH.OVERVIEW.AVAILABLE')
                : t('GLINT_REACH.UNAVAILABLE.BADGE')
            }}
          </span>
        </div>
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t(`GLINT_REACH.MODULES.${module.i18nKey}.TITLE`) }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ t(`GLINT_REACH.MODULES.${module.i18nKey}.DESCRIPTION`) }}
        </p>
      </li>
    </ul>
  </section>
</template>
