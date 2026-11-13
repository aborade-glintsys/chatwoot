<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  VIEWS,
  daysFor,
  groupByDay,
  isSameMonth,
  timeIn,
  titleFor,
} from '../helpers/calendar';

// Month / week / day grid. Items are placed on the day they fall on in
// `timezone`; navigation is purely date based.
const props = defineProps({
  items: { type: Array, default: () => [] },
  view: { type: String, default: 'month' },
  anchor: { type: String, required: true },
  today: { type: String, required: true },
  timezone: { type: String, required: true },
});
const emit = defineEmits(['update:view', 'navigate', 'today', 'open']);

const { t } = useI18n();
const days = computed(() => daysFor(props.view, props.anchor));
const byDay = computed(() => groupByDay(props.items, props.timezone));
const title = computed(() => titleFor(props.view, props.anchor));
const WEEKDAYS = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

const statusClass = status =>
  ({
    pending: 'bg-n-blue-3 text-n-blue-11',
    dispatching: 'bg-n-amber-3 text-n-amber-11',
    dispatched: 'bg-n-teal-3 text-n-teal-11',
    failed: 'bg-n-ruby-3 text-n-ruby-11',
  })[status] || 'bg-n-alpha-2 text-n-slate-11';
</script>

<template>
  <section class="flex flex-col gap-3" data-testid="calendar-view">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div class="flex items-center gap-1">
        <Button
          size="sm"
          variant="ghost"
          icon="i-lucide-chevron-left"
          class="rtl:rotate-180"
          :aria-label="t('GLINT_REACH.CALENDAR.PREVIOUS')"
          data-testid="calendar-prev"
          @click="emit('navigate', -1)"
        />
        <Button
          size="sm"
          variant="faded"
          :label="t('GLINT_REACH.CALENDAR.TODAY')"
          @click="emit('today')"
        />
        <Button
          size="sm"
          variant="ghost"
          icon="i-lucide-chevron-right"
          class="rtl:rotate-180"
          :aria-label="t('GLINT_REACH.CALENDAR.NEXT')"
          data-testid="calendar-next"
          @click="emit('navigate', 1)"
        />
        <h2
          class="mb-0 text-base font-medium ltr:ml-2 rtl:mr-2 text-n-slate-12"
          data-testid="calendar-title"
        >
          {{ title }}
        </h2>
      </div>
      <div class="flex gap-1" role="group">
        <Button
          v-for="option in VIEWS"
          :key="option"
          size="sm"
          :variant="view === option ? 'solid' : 'ghost'"
          :label="t(`GLINT_REACH.CALENDAR.VIEWS.${option.toUpperCase()}`)"
          :data-testid="`calendar-view-${option}`"
          @click="emit('update:view', option)"
        />
      </div>
    </div>

    <div
      class="grid border rounded-xl border-n-weak overflow-hidden"
      :class="view === 'day' ? 'grid-cols-1' : 'grid-cols-7'"
    >
      <template v-if="view !== 'day'">
        <div
          v-for="weekday in WEEKDAYS"
          :key="weekday"
          class="px-2 py-1 text-xs font-medium border-b text-n-slate-11 border-n-weak bg-n-alpha-1"
        >
          {{ t(`GLINT_REACH.CALENDAR.WEEKDAYS.${weekday}`) }}
        </div>
      </template>
      <div
        v-for="day in days"
        :key="day"
        class="flex flex-col gap-1 p-1.5 border-b ltr:border-r rtl:border-l border-n-weak"
        :class="[
          view === 'month' ? 'min-h-24' : 'min-h-48',
          view === 'month' && !isSameMonth(day, anchor)
            ? 'bg-n-alpha-1 opacity-60'
            : '',
        ]"
        :data-testid="`calendar-day-${day}`"
      >
        <span
          class="text-xs w-fit"
          :class="
            day === today
              ? 'px-1.5 rounded-full bg-glint-reach text-white font-semibold'
              : 'text-n-slate-11'
          "
        >
          {{ Number(day.slice(8, 10)) }}
        </span>
        <button
          v-for="item in byDay[day] || []"
          :key="item.id"
          type="button"
          class="flex flex-col w-full gap-0.5 px-1.5 py-1 text-xs rounded ltr:text-left rtl:text-right"
          :class="statusClass(item.status)"
          :data-testid="`calendar-item-${item.id}`"
          @click="emit('open', item)"
        >
          <span class="font-medium truncate">
            {{
              t('GLINT_REACH.CALENDAR.ITEM_LABEL', {
                time: timeIn(item.scheduledAt, timezone),
                platform: t(
                  `GLINT_REACH.PLATFORMS.${item.variant.platform.toUpperCase()}`
                ),
              })
            }}
          </span>
          <span class="truncate">{{ item.contentItem.title }}</span>
        </button>
      </div>
    </div>
    <p
      v-if="!items.length"
      class="mb-0 text-sm text-center text-n-slate-11"
      data-testid="calendar-empty"
    >
      {{ t('GLINT_REACH.CALENDAR.EMPTY') }}
    </p>
  </section>
</template>
