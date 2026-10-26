<script setup>
import { useI18n } from 'vue-i18n';

// Read-only list of a campaign's content items and their platform variants.
// Editing content arrives in a later phase; the API already supports it.
defineProps({
  items: { type: Array, default: () => [] },
});

const { t } = useI18n();
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
      <p v-if="!item.variants.length" class="mb-0 text-xs text-n-slate-10">
        {{ t('GLINT_REACH.CONTENT.NO_VARIANTS') }}
      </p>
      <ul v-else class="grid gap-2 sm:grid-cols-2">
        <li
          v-for="variant in item.variants"
          :key="variant.id"
          class="flex flex-col gap-1.5 p-3 rounded-lg bg-n-alpha-1"
        >
          <div class="flex items-center justify-between text-xs">
            <span class="font-medium text-n-slate-12">
              {{ t(`GLINT_REACH.PLATFORMS.${variant.platform.toUpperCase()}`) }}
            </span>
            <span class="text-n-slate-11">
              {{ t(`GLINT_REACH.STATUSES.${variant.status.toUpperCase()}`) }}
            </span>
          </div>
          <p
            class="mb-0 text-sm whitespace-pre-line break-words line-clamp-4 text-n-slate-12"
          >
            {{ variant.body || t('GLINT_REACH.FORM.NOT_SET') }}
          </p>
          <p
            v-if="variant.hashtags.length"
            class="mb-0 text-xs break-words text-n-slate-11"
          >
            {{ variant.hashtags.map(tag => `#${tag}`).join(' ') }}
          </p>
        </li>
      </ul>
    </li>
  </ul>
</template>
