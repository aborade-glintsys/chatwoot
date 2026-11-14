<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import { useGlintReachCampaignsStore } from 'dashboard/stores/glintReach/campaigns';
import ScheduleDialog from './ScheduleDialog.vue';
import { formatInstant } from '../helpers/calendar';

// Review and scheduling controls for one variant. Buttons follow the
// server-provided `permissions`; every action is re-checked by the server.
const props = defineProps({
  variant: { type: Object, required: true },
  campaignId: { type: Number, default: null },
  // Optional runner (used by the approval queue); defaults to the campaigns store.
  runner: { type: Function, default: null },
});
const emit = defineEmits(['changed']);

const MAX_FEEDBACK = 2000;
const { t } = useI18n();
const campaignsStore = useGlintReachCampaignsStore();
const busy = ref('');
const showReview = ref(false);
const feedback = ref('');
const scheduleDialog = ref(null);
const scheduleError = ref('');

const can = computed(() => props.variant.permissions || {});
const schedule = computed(() => props.variant.schedule);
const approval = computed(() => props.variant.latestApproval);
const target = computed(() => ({
  campaignId: props.campaignId,
  contentItemId: props.variant.contentItemId,
  variantId: props.variant.id,
}));

const run = async (action, params = {}) => {
  busy.value = action;
  try {
    const payload = { lockVersion: props.variant.lockVersion, ...params };
    const body = Object.fromEntries(
      Object.entries(payload).map(([key, value]) => [
        key.replace(/[A-Z]/g, c => `_${c.toLowerCase()}`),
        value,
      ])
    );
    const variant = props.runner
      ? await props.runner(target.value, action, body)
      : await campaignsStore.runWorkflow(target.value, action, body);
    emit('changed', variant);
    return variant;
  } finally {
    busy.value = '';
  }
};

const act = async (action, successKey, params) => {
  try {
    await run(action, params);
    useAlert(t(successKey));
  } catch (error) {
    useAlert(error.message || t('GLINT_REACH.WORKFLOW.FAILED'));
  }
};

const review = async decision => {
  if (decision === 'changes_requested' && !feedback.value.trim()) {
    useAlert(t('GLINT_REACH.WORKFLOW.FEEDBACK_REQUIRED'));
    return;
  }
  try {
    await run('review', { decision, feedback: feedback.value.trim() });
    showReview.value = false;
    feedback.value = '';
    useAlert(
      t(
        decision === 'approved'
          ? 'GLINT_REACH.WORKFLOW.APPROVED'
          : 'GLINT_REACH.WORKFLOW.CHANGES_SENT'
      )
    );
  } catch (error) {
    useAlert(error.message || t('GLINT_REACH.WORKFLOW.FAILED'));
  }
};

const openSchedule = () => {
  scheduleError.value = '';
  scheduleDialog.value?.open(
    props.variant.status === 'scheduled' ? schedule.value : null
  );
};

const submitSchedule = async values => {
  scheduleError.value = '';
  try {
    await run('schedule', values);
    scheduleDialog.value?.close();
    useAlert(t('GLINT_REACH.WORKFLOW.SCHEDULED'));
  } catch (error) {
    scheduleError.value = error.message || t('GLINT_REACH.WORKFLOW.FAILED');
  }
};
</script>

<template>
  <div class="flex flex-col gap-2" data-testid="workflow-panel">
    <div
      v-if="schedule"
      class="flex flex-col gap-1 px-3 py-2 text-xs rounded-lg"
      :class="
        schedule.status === 'failed'
          ? 'bg-n-ruby-3 text-n-ruby-11'
          : 'bg-n-alpha-2 text-n-slate-12'
      "
      data-testid="workflow-schedule"
    >
      <span class="font-medium">
        {{
          t('GLINT_REACH.WORKFLOW.SCHEDULED_FOR', {
            time: formatInstant(schedule.scheduledAt, schedule.timezone),
          })
        }}
      </span>
      <span v-if="schedule.errorMessage">{{ schedule.errorMessage }}</span>
    </div>

    <p
      v-if="
        approval &&
        approval.decision === 'changes_requested' &&
        variant.status === 'changes_requested'
      "
      class="px-3 py-2 mb-0 text-xs break-words rounded-lg bg-n-amber-3 text-n-amber-11"
      data-testid="workflow-feedback"
    >
      {{
        t('GLINT_REACH.WORKFLOW.FEEDBACK_FROM', {
          name: approval.reviewer?.name || '',
        })
      }}
      {{ approval.feedback }}
    </p>

    <div class="flex flex-wrap gap-1">
      <Button
        v-if="can.submit"
        size="xs"
        icon="i-lucide-send"
        data-testid="workflow-submit"
        :label="t('GLINT_REACH.WORKFLOW.SUBMIT')"
        :is-loading="busy === 'submit'"
        @click="act('submit', 'GLINT_REACH.WORKFLOW.SUBMITTED')"
      />
      <Button
        v-if="can.review"
        size="xs"
        icon="i-lucide-check-check"
        data-testid="workflow-review"
        :label="t('GLINT_REACH.WORKFLOW.REVIEW')"
        @click="showReview = !showReview"
      />
      <Button
        v-if="can.withdraw"
        size="xs"
        variant="ghost"
        icon="i-lucide-undo-2"
        data-testid="workflow-withdraw"
        :label="t('GLINT_REACH.WORKFLOW.WITHDRAW')"
        :is-loading="busy === 'withdraw'"
        @click="act('withdraw', 'GLINT_REACH.WORKFLOW.WITHDRAWN')"
      />
      <Button
        v-if="can.schedule"
        size="xs"
        icon="i-lucide-calendar-clock"
        data-testid="workflow-schedule-button"
        :label="
          variant.status === 'scheduled'
            ? t('GLINT_REACH.WORKFLOW.RESCHEDULE')
            : t('GLINT_REACH.WORKFLOW.SCHEDULE.CONFIRM')
        "
        @click="openSchedule"
      />
      <Button
        v-if="can.cancelSchedule"
        size="xs"
        variant="ghost"
        color="ruby"
        icon="i-lucide-calendar-x"
        data-testid="workflow-cancel"
        :label="t('GLINT_REACH.WORKFLOW.CANCEL_SCHEDULE')"
        :is-loading="busy === 'cancel_schedule'"
        @click="act('cancel_schedule', 'GLINT_REACH.WORKFLOW.CANCELLED')"
      />
      <Button
        v-if="can.reopen"
        size="xs"
        variant="ghost"
        icon="i-lucide-pencil-line"
        data-testid="workflow-reopen"
        :label="t('GLINT_REACH.WORKFLOW.REOPEN')"
        :is-loading="busy === 'reopen'"
        @click="act('reopen', 'GLINT_REACH.WORKFLOW.REOPENED')"
      />
    </div>
    <p
      v-if="variant.status === 'in_review' && !can.review && !can.withdraw"
      class="mb-0 text-xs text-n-slate-10"
    >
      {{ t('GLINT_REACH.WORKFLOW.WAITING_FOR_REVIEW') }}
    </p>
    <p
      v-if="variant.status === 'in_review' && can.withdraw && !can.review"
      class="mb-0 text-xs text-n-slate-10"
      data-testid="workflow-self-review-hint"
    >
      {{ t('GLINT_REACH.WORKFLOW.SELF_REVIEW_HINT') }}
    </p>

    <form
      v-if="showReview && can.review"
      class="flex flex-col gap-2"
      data-testid="workflow-review-form"
      @submit.prevent="review('approved')"
    >
      <label class="flex flex-col gap-1 text-xs text-n-slate-11">
        {{ t('GLINT_REACH.WORKFLOW.FEEDBACK') }}
        <textarea
          v-model="feedback"
          rows="2"
          :maxlength="MAX_FEEDBACK"
          class="!mb-0 text-sm"
          data-testid="workflow-feedback-input"
        />
      </label>
      <div class="flex flex-wrap gap-1">
        <Button
          type="submit"
          size="xs"
          color="teal"
          data-testid="workflow-approve"
          :label="t('GLINT_REACH.WORKFLOW.APPROVE')"
          :is-loading="busy === 'review'"
        />
        <Button
          type="button"
          size="xs"
          variant="faded"
          color="amber"
          data-testid="workflow-request-changes"
          :label="t('GLINT_REACH.WORKFLOW.REQUEST_CHANGES')"
          :disabled="busy === 'review'"
          @click="review('changes_requested')"
        />
      </div>
    </form>

    <ScheduleDialog
      ref="scheduleDialog"
      :is-saving="busy === 'schedule'"
      :server-error="scheduleError"
      @submit="submitSchedule"
    />
  </div>
</template>
