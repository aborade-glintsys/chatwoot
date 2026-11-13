<script setup>
import { useI18n } from 'vue-i18n';
import { formatInstant } from '../helpers/calendar';

// Table of schedules in the selected range, newest state per item.
defineProps({
  items: { type: Array, default: () => [] },
  timezone: { type: String, required: true },
});
const emit = defineEmits(['open']);
const { t } = useI18n();
</script>

<template>
  <p
    v-if="!items.length"
    class="px-4 py-8 mb-0 text-sm text-center border border-dashed rounded-xl border-n-weak text-n-slate-11"
    data-testid="schedule-list-empty"
  >
    {{ t('GLINT_REACH.CALENDAR.EMPTY') }}
  </p>
  <div v-else class="overflow-x-auto border rounded-xl border-n-weak">
    <table class="w-full text-sm" data-testid="schedule-list">
      <thead
        class="text-xs ltr:text-left rtl:text-right text-n-slate-11 bg-n-alpha-1"
      >
        <tr>
          <th class="px-3 py-2 font-medium">
            {{ t('GLINT_REACH.CALENDAR.COLUMNS.TIME') }}
          </th>
          <th class="px-3 py-2 font-medium">
            {{ t('GLINT_REACH.CALENDAR.COLUMNS.CONTENT') }}
          </th>
          <th class="px-3 py-2 font-medium">
            {{ t('GLINT_REACH.CALENDAR.COLUMNS.CHANNEL') }}
          </th>
          <th class="px-3 py-2 font-medium">
            {{ t('GLINT_REACH.CALENDAR.COLUMNS.STATUS') }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="item in items"
          :key="item.id"
          class="border-t cursor-pointer border-n-weak hover:bg-n-alpha-1"
          :data-testid="`schedule-row-${item.id}`"
          @click="emit('open', item)"
        >
          <td class="px-3 py-2 whitespace-nowrap text-n-slate-12">
            {{ formatInstant(item.scheduledAt, timezone) }}
          </td>
          <td class="px-3 py-2">
            <span class="block font-medium text-n-slate-12">{{
              item.contentItem.title
            }}</span>
            <span class="block text-xs text-n-slate-11">{{
              item.campaign.name
            }}</span>
          </td>
          <td class="px-3 py-2 text-n-slate-12">
            {{
              t(`GLINT_REACH.PLATFORMS.${item.variant.platform.toUpperCase()}`)
            }}
          </td>
          <td class="px-3 py-2">
            <span class="text-xs text-n-slate-12">
              {{
                t(
                  `GLINT_REACH.CALENDAR.SCHEDULE_STATUS.${item.status.toUpperCase()}`
                )
              }}
            </span>
            <span v-if="item.errorMessage" class="block text-xs text-n-ruby-11">
              {{ item.errorMessage }}
            </span>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
