<script setup>
import { ref, reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  LIMITS,
  CHANNELS,
  OBJECTIVES,
  validateCampaignBrief,
  epochToDateInput,
  dateInputToIso,
} from '../helpers/validation';

const props = defineProps({
  campaign: { type: Object, default: null },
  readonly: { type: Boolean, default: false },
  isSaving: { type: Boolean, default: false },
  serverErrorFields: { type: Array, default: () => [] },
  serverMessage: { type: String, default: '' },
});

const emit = defineEmits(['submit']);
const { t } = useI18n();

const source = props.campaign || {};
const form = reactive({
  name: source.name || '',
  objective: source.objective || '',
  targetAudience: source.targetAudience || '',
  offer: source.offer || '',
  keyMessage: source.keyMessage || '',
  desiredAction: source.desiredAction || '',
  channels: [...(source.channels || [])],
  startsAt: epochToDateInput(source.startsAt),
  endsAt: epochToDateInput(source.endsAt),
  brief: source.brief || '',
});

const submitted = ref(false);
const clientErrors = computed(() =>
  submitted.value ? validateCampaignBrief(form) : {}
);

const MAX = {
  name: LIMITS.NAME,
  desiredAction: LIMITS.DESIRED_ACTION,
  targetAudience: LIMITS.CAMPAIGN_TEXT,
  brief: LIMITS.CAMPAIGN_TEXT,
};

const errorFor = field => {
  const key = clientErrors.value[field];
  if (key)
    return t(`GLINT_REACH.VALIDATION.${key}`, {
      max: MAX[field] || LIMITS.TEXT,
    });
  if (props.serverErrorFields.includes(field))
    return t('GLINT_REACH.VALIDATION.SERVER_REJECTED');
  return '';
};

const toggleChannel = channel => {
  form.channels = form.channels.includes(channel)
    ? form.channels.filter(item => item !== channel)
    : [...form.channels, channel];
};

const onSubmit = () => {
  if (props.readonly) return;
  submitted.value = true;
  if (Object.keys(validateCampaignBrief(form)).length) return;
  emit('submit', {
    ...form,
    name: form.name.trim(),
    startsAt: dateInputToIso(form.startsAt),
    endsAt: dateInputToIso(form.endsAt),
  });
};
</script>

<template>
  <form
    class="flex flex-col gap-6"
    novalidate
    data-testid="campaign-brief-form"
    @submit.prevent="onSubmit"
  >
    <p
      v-if="serverMessage"
      role="alert"
      class="px-4 py-3 mb-0 text-sm rounded-lg bg-n-ruby-3 text-n-ruby-11"
    >
      {{ serverMessage }}
    </p>

    <fieldset :disabled="readonly" class="flex flex-col gap-5 min-w-0">
      <Input
        id="glint-reach-brief-name"
        v-model="form.name"
        :label="`${t('GLINT_REACH.BRIEF.FIELDS.NAME')} *`"
        :placeholder="t('GLINT_REACH.BRIEF.PLACEHOLDERS.NAME')"
        :maxlength="LIMITS.NAME"
        required
        :disabled="readonly"
        :message="errorFor('name')"
        :message-type="errorFor('name') ? 'error' : 'info'"
        :aria-invalid="Boolean(errorFor('name'))"
      />

      <div class="flex flex-col gap-1">
        <label
          for="glint-reach-brief-objective"
          class="mb-0.5 text-heading-3 text-n-slate-12"
        >
          {{ `${t('GLINT_REACH.BRIEF.FIELDS.OBJECTIVE')} *` }}
        </label>
        <select
          id="glint-reach-brief-objective"
          v-model="form.objective"
          required
          :disabled="readonly"
          :aria-invalid="Boolean(errorFor('objective'))"
          :aria-describedby="
            errorFor('objective')
              ? 'glint-reach-brief-objective-error'
              : undefined
          "
          class="w-full max-w-xs px-3 py-2 text-sm rounded-lg outline outline-1 -outline-offset-1 bg-n-surface-1 !mb-0 disabled:opacity-50"
          :class="errorFor('objective') ? 'outline-n-ruby-8' : 'outline-n-weak'"
        >
          <option value="" disabled>
            {{ t('GLINT_REACH.BRIEF.PLACEHOLDERS.OBJECTIVE') }}
          </option>
          <option
            v-for="objective in OBJECTIVES"
            :key="objective"
            :value="objective"
          >
            {{ t(`GLINT_REACH.OBJECTIVES.${objective.toUpperCase()}`) }}
          </option>
        </select>
        <p
          v-if="errorFor('objective')"
          id="glint-reach-brief-objective-error"
          role="alert"
          class="mt-1 mb-0 text-label-small text-n-ruby-9"
        >
          {{ errorFor('objective') }}
        </p>
      </div>

      <TextArea
        id="glint-reach-brief-audience"
        v-model="form.targetAudience"
        :label="t('GLINT_REACH.BRIEF.FIELDS.AUDIENCE')"
        :placeholder="t('GLINT_REACH.BRIEF.PLACEHOLDERS.AUDIENCE')"
        :max-length="LIMITS.CAMPAIGN_TEXT"
        :disabled="readonly"
        show-character-count
        auto-height
        :message="errorFor('targetAudience')"
        :message-type="errorFor('targetAudience') ? 'error' : 'info'"
      />
      <TextArea
        id="glint-reach-brief-offer"
        v-model="form.offer"
        :label="t('GLINT_REACH.BRIEF.FIELDS.OFFER')"
        :placeholder="t('GLINT_REACH.BRIEF.PLACEHOLDERS.OFFER')"
        :max-length="LIMITS.TEXT"
        :disabled="readonly"
        show-character-count
        auto-height
        :message="errorFor('offer')"
        :message-type="errorFor('offer') ? 'error' : 'info'"
      />
      <TextArea
        id="glint-reach-brief-key-message"
        v-model="form.keyMessage"
        :label="t('GLINT_REACH.BRIEF.FIELDS.KEY_MESSAGE')"
        :placeholder="t('GLINT_REACH.BRIEF.PLACEHOLDERS.KEY_MESSAGE')"
        :max-length="LIMITS.TEXT"
        :disabled="readonly"
        show-character-count
        auto-height
        :message="errorFor('keyMessage')"
        :message-type="errorFor('keyMessage') ? 'error' : 'info'"
      />
      <Input
        id="glint-reach-brief-desired-action"
        v-model="form.desiredAction"
        :label="t('GLINT_REACH.BRIEF.FIELDS.DESIRED_ACTION')"
        :placeholder="t('GLINT_REACH.BRIEF.PLACEHOLDERS.DESIRED_ACTION')"
        :maxlength="LIMITS.DESIRED_ACTION"
        :disabled="readonly"
        :message="errorFor('desiredAction')"
        :message-type="errorFor('desiredAction') ? 'error' : 'info'"
      />

      <fieldset class="flex flex-col gap-2">
        <legend class="mb-2 text-heading-3 text-n-slate-12">
          {{ t('GLINT_REACH.BRIEF.FIELDS.CHANNELS') }}
        </legend>
        <div class="flex flex-wrap gap-2">
          <label
            v-for="channel in CHANNELS"
            :key="channel"
            class="inline-flex items-center gap-2 px-3 py-1.5 text-sm rounded-full outline outline-1 -outline-offset-1 cursor-pointer select-none transition-colors has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-n-brand"
            :class="
              form.channels.includes(channel)
                ? 'outline-glint-reach bg-glint-reach/10 text-n-slate-12'
                : 'outline-n-weak text-n-slate-11 hover:outline-n-slate-6'
            "
          >
            <input
              type="checkbox"
              class="sr-only"
              :value="channel"
              :checked="form.channels.includes(channel)"
              :disabled="readonly"
              @change="toggleChannel(channel)"
            />
            <span
              class="size-3.5"
              :class="
                form.channels.includes(channel)
                  ? 'i-lucide-check'
                  : 'i-lucide-plus'
              "
              aria-hidden="true"
            />
            {{ t(`GLINT_REACH.PLATFORMS.${channel.toUpperCase()}`) }}
          </label>
        </div>
        <p
          v-if="errorFor('channels')"
          role="alert"
          class="mb-0 text-label-small text-n-ruby-9"
        >
          {{ errorFor('channels') }}
        </p>
      </fieldset>

      <div class="grid gap-5 sm:grid-cols-2">
        <Input
          id="glint-reach-brief-starts-at"
          v-model="form.startsAt"
          type="date"
          :label="t('GLINT_REACH.BRIEF.FIELDS.STARTS_AT')"
          :disabled="readonly"
          :message="errorFor('startsAt')"
          :message-type="errorFor('startsAt') ? 'error' : 'info'"
        />
        <Input
          id="glint-reach-brief-ends-at"
          v-model="form.endsAt"
          type="date"
          :label="t('GLINT_REACH.BRIEF.FIELDS.ENDS_AT')"
          :min="form.startsAt"
          :disabled="readonly"
          :message="errorFor('endsAt')"
          :message-type="errorFor('endsAt') ? 'error' : 'info'"
        />
      </div>

      <TextArea
        id="glint-reach-brief-notes"
        v-model="form.brief"
        :label="t('GLINT_REACH.BRIEF.FIELDS.NOTES')"
        :placeholder="t('GLINT_REACH.BRIEF.PLACEHOLDERS.NOTES')"
        :max-length="LIMITS.CAMPAIGN_TEXT"
        :disabled="readonly"
        show-character-count
        auto-height
        :message="errorFor('brief')"
        :message-type="errorFor('brief') ? 'error' : 'info'"
      />
    </fieldset>

    <div v-if="!readonly" class="flex items-center gap-3">
      <Button
        type="submit"
        :label="
          campaign ? t('GLINT_REACH.BRIEF.SAVE') : t('GLINT_REACH.BRIEF.CREATE')
        "
        :is-loading="isSaving"
        :disabled="isSaving"
      />
    </div>
  </form>
</template>
