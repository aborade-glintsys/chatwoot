<script setup>
import { ref, computed, inject } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import {
  browserTimezone,
  timezoneOptions,
  todayIn,
  dayKeyIn,
  timeIn,
} from '../helpers/calendar';

// Collects a wall-clock date and time plus an explicit IANA time zone. The
// server converts it to UTC and rejects DST gaps and out-of-range times.
const props = defineProps({
  isSaving: { type: Boolean, default: false },
  serverError: { type: String, default: '' },
});
const emit = defineEmits(['submit']);

const { t } = useI18n();
const shell = inject('glintReachShell', ref(null));
const dialog = ref(null);
const date = ref('');
const time = ref('09:00');
const timezone = ref('UTC');
const localError = ref('');

const zones = computed(() => timezoneOptions(timezone.value));
const message = computed(() => localError.value || props.serverError);

// existing: { scheduledAt (epoch seconds), timezone } when rescheduling.
const open = (existing = null) => {
  localError.value = '';
  timezone.value =
    existing?.timezone || shell.value?.timezone || browserTimezone();
  if (existing?.scheduledAt) {
    date.value = dayKeyIn(existing.scheduledAt, timezone.value);
    time.value = timeIn(existing.scheduledAt, timezone.value);
  } else {
    date.value = todayIn(timezone.value);
    time.value = '09:00';
  }
  dialog.value?.open();
};
const close = () => dialog.value?.close();

const submit = () => {
  localError.value = '';
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(date.value) ||
    !/^\d{2}:\d{2}$/.test(time.value)
  ) {
    localError.value = t('GLINT_REACH.WORKFLOW.SCHEDULE.INVALID');
    return;
  }
  emit('submit', {
    date: date.value,
    time: time.value,
    timezone: timezone.value,
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialog"
    :title="t('GLINT_REACH.WORKFLOW.SCHEDULE.TITLE')"
    :description="t('GLINT_REACH.WORKFLOW.SCHEDULE.DESCRIPTION')"
    :confirm-button-label="t('GLINT_REACH.WORKFLOW.SCHEDULE.CONFIRM')"
    :is-loading="isSaving"
    :disable-confirm-button="isSaving"
    @confirm="submit"
  >
    <div class="flex flex-col gap-3" data-testid="schedule-dialog">
      <div class="grid gap-3 sm:grid-cols-2">
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          {{ t('GLINT_REACH.WORKFLOW.SCHEDULE.DATE') }}
          <input
            v-model="date"
            type="date"
            class="!mb-0"
            data-testid="schedule-date"
          />
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          {{ t('GLINT_REACH.WORKFLOW.SCHEDULE.TIME') }}
          <input
            v-model="time"
            type="time"
            step="60"
            class="!mb-0"
            data-testid="schedule-time"
          />
        </label>
      </div>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        {{ t('GLINT_REACH.WORKFLOW.SCHEDULE.TIMEZONE') }}
        <select
          v-model="timezone"
          class="!mb-0"
          data-testid="schedule-timezone"
        >
          <option v-for="zone in zones" :key="zone" :value="zone">
            {{ zone }}
          </option>
        </select>
      </label>
      <p class="mb-0 text-xs text-n-slate-11">
        {{ t('GLINT_REACH.WORKFLOW.SCHEDULE.NOTE') }}
      </p>
      <p
        v-if="message"
        class="px-3 py-2 mb-0 text-sm rounded-lg bg-n-ruby-3 text-n-ruby-11"
        role="alert"
        data-testid="schedule-error"
      >
        {{ message }}
      </p>
    </div>
  </Dialog>
</template>
