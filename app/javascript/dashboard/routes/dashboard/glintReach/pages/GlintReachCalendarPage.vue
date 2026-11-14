<script setup>
import { ref, computed, inject, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useGlintReachCalendarStore } from 'dashboard/stores/glintReach/calendar';
import CalendarView from '../components/CalendarView.vue';
import ScheduleList from '../components/ScheduleList.vue';
import ApprovalQueue from '../components/ApprovalQueue.vue';
import {
  browserTimezone,
  rangeFor,
  shiftAnchor,
  timezoneOptions,
  todayIn,
} from '../helpers/calendar';

const { t } = useI18n();
const router = useRouter();
const store = useGlintReachCalendarStore();
const shell = inject('glintReachShell', ref(null));

const TABS = ['calendar', 'list', 'approvals'];
const STATUS_FILTERS = ['pending', 'dispatching', 'dispatched', 'failed'];
const tab = ref('calendar');
const view = ref('month');
const timezone = ref(shell.value?.timezone || browserTimezone());
const anchor = ref(todayIn(timezone.value));
const statuses = ref([]);
const loadError = ref('');

const today = computed(() => todayIn(timezone.value));
const zones = computed(() => timezoneOptions(timezone.value));
// The list shows the visible month around the anchor.
const range = computed(() =>
  rangeFor(tab.value === 'list' ? 'month' : view.value, anchor.value)
);

const load = async () => {
  if (tab.value === 'approvals') return;
  loadError.value = '';
  try {
    await store.fetchCalendar({
      ...range.value,
      timezone: timezone.value,
      status: statuses.value,
    });
  } catch (error) {
    loadError.value = error.message || t('GLINT_REACH.ERRORS.LOAD_FAILED');
  }
};

const toggleStatus = status => {
  statuses.value = statuses.value.includes(status)
    ? statuses.value.filter(value => value !== status)
    : [...statuses.value, status];
};

const openItem = item =>
  router.push({
    name: 'glint_reach_content_studio_campaign',
    params: { campaignId: item.campaign.id },
  });

watch([tab, view, anchor, timezone, statuses], load, { immediate: true });
</script>

<template>
  <section class="flex flex-col w-full max-w-6xl gap-6 px-6 py-10 mx-auto">
    <header class="flex flex-col gap-2">
      <span class="w-10 h-1 rounded-full bg-glint-reach" />
      <h1 class="mb-0 text-2xl font-semibold text-n-slate-12">
        {{ t('GLINT_REACH.MODULES.CALENDAR.TITLE') }}
      </h1>
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('GLINT_REACH.CALENDAR.DESCRIPTION') }}
      </p>
    </header>

    <div class="flex flex-wrap items-center justify-between gap-3">
      <div class="flex gap-1" role="tablist">
        <Button
          v-for="option in TABS"
          :key="option"
          size="sm"
          role="tab"
          :aria-selected="tab === option"
          :variant="tab === option ? 'solid' : 'ghost'"
          :label="t(`GLINT_REACH.CALENDAR.TABS.${option.toUpperCase()}`)"
          :data-testid="`calendar-tab-${option}`"
          @click="tab = option"
        />
      </div>
      <label
        v-if="tab !== 'approvals'"
        class="flex items-center gap-2 text-xs text-n-slate-11"
      >
        {{ t('GLINT_REACH.WORKFLOW.SCHEDULE.TIMEZONE') }}
        <select
          v-model="timezone"
          class="!mb-0 !w-56 text-sm"
          data-testid="calendar-timezone"
        >
          <option v-for="zone in zones" :key="zone" :value="zone">
            {{ zone }}
          </option>
        </select>
      </label>
    </div>

    <div
      v-if="tab !== 'approvals'"
      class="flex flex-wrap gap-1"
      data-testid="calendar-status-filters"
    >
      <Button
        v-for="status in STATUS_FILTERS"
        :key="status"
        size="xs"
        :variant="statuses.includes(status) ? 'solid' : 'faded'"
        :label="
          t(`GLINT_REACH.CALENDAR.SCHEDULE_STATUS.${status.toUpperCase()}`)
        "
        @click="toggleStatus(status)"
      />
    </div>

    <ApprovalQueue v-if="tab === 'approvals'" />
    <template v-else>
      <div
        v-if="loadError"
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
      <div
        v-else-if="store.uiFlags.isFetching && !store.items.length"
        class="flex justify-center py-10"
      >
        <Spinner />
      </div>
      <CalendarView
        v-else-if="tab === 'calendar'"
        v-model:view="view"
        :items="store.items"
        :anchor="anchor"
        :today="today"
        :timezone="timezone"
        @navigate="direction => (anchor = shiftAnchor(view, anchor, direction))"
        @today="anchor = today"
        @open="openItem"
      />
      <template v-else>
        <div class="flex items-center gap-1">
          <Button
            size="sm"
            variant="ghost"
            icon="i-lucide-chevron-left"
            class="rtl:rotate-180"
            :aria-label="t('GLINT_REACH.CALENDAR.PREVIOUS')"
            @click="anchor = shiftAnchor('month', anchor, -1)"
          />
          <Button
            size="sm"
            variant="ghost"
            icon="i-lucide-chevron-right"
            class="rtl:rotate-180"
            :aria-label="t('GLINT_REACH.CALENDAR.NEXT')"
            @click="anchor = shiftAnchor('month', anchor, 1)"
          />
          <span class="text-sm text-n-slate-11">
            {{
              t('GLINT_REACH.CALENDAR.RANGE', {
                from: range.from,
                to: range.to,
              })
            }}
          </span>
        </div>
        <ScheduleList
          :items="store.items"
          :timezone="timezone"
          @open="openItem"
        />
      </template>
    </template>
  </section>
</template>
