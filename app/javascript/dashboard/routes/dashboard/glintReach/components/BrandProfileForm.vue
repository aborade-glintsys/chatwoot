<script setup>
import { ref, computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ChipListInput from './ChipListInput.vue';
import languages from 'dashboard/components/widgets/conversation/advancedFilterItems/languages';
import { LIMITS, validateBrandProfile } from '../helpers/validation';

const props = defineProps({
  profile: { type: Object, default: null },
  isSaving: { type: Boolean, default: false },
  // camelCased attribute names returned by the server on 422
  serverErrorFields: { type: Array, default: () => [] },
  serverMessage: { type: String, default: '' },
  showCancel: { type: Boolean, default: false },
});

const emit = defineEmits(['submit', 'cancel']);
const { t } = useI18n();

const TEXT_SECTIONS = [
  {
    titleKey: 'ABOUT',
    fields: [
      { key: 'description', i18n: 'DESCRIPTION' },
      { key: 'productsServices', i18n: 'PRODUCTS_SERVICES' },
    ],
  },
  {
    titleKey: 'AUDIENCE',
    fields: [
      { key: 'targetAudience', i18n: 'TARGET_AUDIENCE' },
      { key: 'geographicMarket', i18n: 'GEOGRAPHIC_MARKET' },
    ],
  },
  {
    titleKey: 'VOICE',
    fields: [
      { key: 'voiceAndTone', i18n: 'VOICE_AND_TONE' },
      { key: 'messagingGuidelines', i18n: 'MESSAGING_GUIDELINES' },
      { key: 'prohibitedClaims', i18n: 'PROHIBITED_CLAIMS' },
    ],
  },
];

const source = props.profile || {};
const form = reactive({
  name: source.name || '',
  websiteUrl: source.websiteUrl || '',
  description: source.description || '',
  productsServices: source.productsServices || '',
  targetAudience: source.targetAudience || '',
  geographicMarket: source.geographicMarket || '',
  preferredLanguages: [...(source.preferredLanguages || [])],
  voiceAndTone: source.voiceAndTone || '',
  messagingGuidelines: source.messagingGuidelines || '',
  prohibitedClaims: source.prohibitedClaims || '',
  approvedCtas: [...(source.approvedCtas || [])],
});

const submitted = ref(false);
const clientErrors = computed(() =>
  submitted.value ? validateBrandProfile(form) : {}
);

const languageOptions = languages.map(({ id, name }) => ({
  value: id,
  label: name,
}));

const maxFor = field =>
  ({
    name: LIMITS.NAME,
    websiteUrl: LIMITS.URL,
    preferredLanguages: LIMITS.LANGUAGES,
    approvedCtas:
      clientErrors.value.approvedCtas === 'TOO_MANY' ? LIMITS.CTAS : LIMITS.CTA,
  })[field] || LIMITS.TEXT;

const errorFor = field => {
  const key = clientErrors.value[field];
  if (key) return t(`GLINT_REACH.VALIDATION.${key}`, { max: maxFor(field) });
  if (props.serverErrorFields.includes(field))
    return t('GLINT_REACH.VALIDATION.SERVER_REJECTED');
  return '';
};

const onSubmit = () => {
  submitted.value = true;
  if (Object.keys(validateBrandProfile(form)).length) return;
  emit('submit', {
    ...form,
    name: form.name.trim(),
    websiteUrl: form.websiteUrl.trim(),
  });
};
</script>

<template>
  <form
    class="flex flex-col gap-8"
    novalidate
    data-testid="brand-profile-form"
    @submit.prevent="onSubmit"
  >
    <p
      v-if="serverMessage"
      role="alert"
      class="px-4 py-3 mb-0 text-sm rounded-lg bg-n-ruby-3 text-n-ruby-11"
    >
      {{ serverMessage }}
    </p>

    <fieldset class="flex flex-col gap-5">
      <legend class="mb-4 text-base font-medium text-n-slate-12">
        {{ t('GLINT_REACH.BRAND_PROFILE.SECTIONS.IDENTITY') }}
      </legend>
      <Input
        id="glint-reach-brand-name"
        v-model="form.name"
        :label="`${t('GLINT_REACH.BRAND_PROFILE.FIELDS.NAME')} *`"
        :placeholder="t('GLINT_REACH.BRAND_PROFILE.PLACEHOLDERS.NAME')"
        :maxlength="LIMITS.NAME"
        required
        autocomplete="organization"
        :message="errorFor('name')"
        :message-type="errorFor('name') ? 'error' : 'info'"
        :aria-invalid="Boolean(errorFor('name'))"
      />
      <Input
        id="glint-reach-brand-website"
        v-model="form.websiteUrl"
        type="url"
        inputmode="url"
        autocomplete="url"
        autocapitalize="off"
        autocorrect="off"
        spellcheck="false"
        :label="t('GLINT_REACH.BRAND_PROFILE.FIELDS.WEBSITE_URL')"
        :placeholder="t('GLINT_REACH.BRAND_PROFILE.PLACEHOLDERS.WEBSITE_URL')"
        :maxlength="LIMITS.URL"
        :message="
          errorFor('websiteUrl') ||
          t('GLINT_REACH.BRAND_PROFILE.HELP.WEBSITE_URL')
        "
        :message-type="errorFor('websiteUrl') ? 'error' : 'info'"
        :aria-invalid="Boolean(errorFor('websiteUrl'))"
      />
    </fieldset>

    <fieldset
      v-for="section in TEXT_SECTIONS"
      :key="section.titleKey"
      class="flex flex-col gap-5"
    >
      <legend class="mb-4 text-base font-medium text-n-slate-12">
        {{ t(`GLINT_REACH.BRAND_PROFILE.SECTIONS.${section.titleKey}`) }}
      </legend>
      <TextArea
        v-for="field in section.fields"
        :id="`glint-reach-brand-${field.key}`"
        :key="field.key"
        v-model="form[field.key]"
        :label="t(`GLINT_REACH.BRAND_PROFILE.FIELDS.${field.i18n}`)"
        :placeholder="t(`GLINT_REACH.BRAND_PROFILE.PLACEHOLDERS.${field.i18n}`)"
        :max-length="LIMITS.TEXT"
        show-character-count
        auto-height
        :message="errorFor(field.key)"
        :message-type="errorFor(field.key) ? 'error' : 'info'"
      />
      <ChipListInput
        v-if="section.titleKey === 'AUDIENCE'"
        v-model="form.preferredLanguages"
        :label="t('GLINT_REACH.BRAND_PROFILE.FIELDS.PREFERRED_LANGUAGES')"
        :placeholder="
          t('GLINT_REACH.BRAND_PROFILE.PLACEHOLDERS.PREFERRED_LANGUAGES')
        "
        :options="languageOptions"
        :max-items="LIMITS.LANGUAGES"
        :message="errorFor('preferredLanguages')"
        message-type="error"
      />
      <ChipListInput
        v-if="section.titleKey === 'VOICE'"
        v-model="form.approvedCtas"
        :label="t('GLINT_REACH.BRAND_PROFILE.FIELDS.APPROVED_CTAS')"
        :placeholder="t('GLINT_REACH.BRAND_PROFILE.PLACEHOLDERS.APPROVED_CTAS')"
        :max-items="LIMITS.CTAS"
        :max-length="LIMITS.CTA"
        :message="
          errorFor('approvedCtas') ||
          t('GLINT_REACH.BRAND_PROFILE.HELP.APPROVED_CTAS', {
            max: LIMITS.CTAS,
          })
        "
        :message-type="errorFor('approvedCtas') ? 'error' : 'info'"
      />
    </fieldset>

    <div class="flex items-center gap-3">
      <Button
        type="submit"
        :label="t('GLINT_REACH.FORM.SAVE')"
        :is-loading="isSaving"
        :disabled="isSaving"
      />
      <Button
        v-if="showCancel"
        type="button"
        variant="faded"
        color="slate"
        :label="t('GLINT_REACH.FORM.CANCEL')"
        :disabled="isSaving"
        @click="emit('cancel')"
      />
    </div>
  </form>
</template>
