<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import languages from 'dashboard/components/widgets/conversation/advancedFilterItems/languages';
import { isValidWebsiteUrl } from '../helpers/validation';

// Read-only view. All values are untrusted user input and are rendered only via
// text interpolation (no v-html).
const props = defineProps({
  profile: { type: Object, required: true },
});

const { t } = useI18n();

const TEXT_FIELDS = [
  { key: 'description', i18n: 'DESCRIPTION' },
  { key: 'productsServices', i18n: 'PRODUCTS_SERVICES' },
  { key: 'targetAudience', i18n: 'TARGET_AUDIENCE' },
  { key: 'geographicMarket', i18n: 'GEOGRAPHIC_MARKET' },
  { key: 'voiceAndTone', i18n: 'VOICE_AND_TONE' },
  { key: 'messagingGuidelines', i18n: 'MESSAGING_GUIDELINES' },
  { key: 'prohibitedClaims', i18n: 'PROHIBITED_CLAIMS' },
];

const languageNames = computed(() =>
  (props.profile.preferredLanguages || []).map(
    code => languages.find(({ id }) => id === code)?.name || code
  )
);

// Only link URLs that pass the same http(s) check as the server.
const safeWebsiteUrl = computed(() =>
  props.profile.websiteUrl && isValidWebsiteUrl(props.profile.websiteUrl)
    ? props.profile.websiteUrl
    : ''
);
</script>

<template>
  <dl class="grid gap-x-8 gap-y-6 sm:grid-cols-[12rem_1fr]">
    <dt class="text-sm font-medium text-n-slate-11">
      {{ t('GLINT_REACH.BRAND_PROFILE.FIELDS.WEBSITE_URL') }}
    </dt>
    <dd class="m-0 text-sm text-n-slate-12">
      <a
        v-if="safeWebsiteUrl"
        :href="safeWebsiteUrl"
        target="_blank"
        rel="noopener noreferrer nofollow"
        class="break-all text-n-blue-11 hover:underline"
      >
        {{ safeWebsiteUrl }}
      </a>
      <span v-else class="text-n-slate-10">
        {{ t('GLINT_REACH.FORM.NOT_SET') }}
      </span>
    </dd>

    <template v-for="field in TEXT_FIELDS" :key="field.key">
      <dt class="text-sm font-medium text-n-slate-11">
        {{ t(`GLINT_REACH.BRAND_PROFILE.FIELDS.${field.i18n}`) }}
      </dt>
      <dd
        class="m-0 text-sm whitespace-pre-line break-words text-n-slate-12"
        :class="{ '!text-n-slate-10': !profile[field.key] }"
      >
        {{ profile[field.key] || t('GLINT_REACH.FORM.NOT_SET') }}
      </dd>
    </template>

    <dt class="text-sm font-medium text-n-slate-11">
      {{ t('GLINT_REACH.BRAND_PROFILE.FIELDS.PREFERRED_LANGUAGES') }}
    </dt>
    <dd class="flex flex-wrap gap-2 m-0 text-sm text-n-slate-12">
      <span
        v-for="name in languageNames"
        :key="name"
        class="px-2.5 py-0.5 rounded-full bg-n-alpha-2"
      >
        {{ name }}
      </span>
      <span v-if="!languageNames.length" class="text-n-slate-10">
        {{ t('GLINT_REACH.FORM.NOT_SET') }}
      </span>
    </dd>

    <dt class="text-sm font-medium text-n-slate-11">
      {{ t('GLINT_REACH.BRAND_PROFILE.FIELDS.APPROVED_CTAS') }}
    </dt>
    <dd class="flex flex-wrap gap-2 m-0 text-sm text-n-slate-12">
      <span
        v-for="cta in profile.approvedCtas"
        :key="cta"
        class="px-2.5 py-0.5 rounded-full bg-n-alpha-2"
      >
        {{ cta }}
      </span>
      <span v-if="!profile.approvedCtas?.length" class="text-n-slate-10">
        {{ t('GLINT_REACH.FORM.NOT_SET') }}
      </span>
    </dd>
  </dl>
</template>
