<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import { useGlintReachCampaignsStore } from 'dashboard/stores/glintReach/campaigns';
import {
  useGlintReachGenerationsStore,
  isActiveGeneration,
} from 'dashboard/stores/glintReach/generations';
import ChipListInput from './ChipListInput.vue';
import GenerationStatus from './GenerationStatus.vue';

// One platform variant: manual editing, ready/draft, and AI regenerate,
// rewrite and suggestions. Ready variants are protected from AI changes.
const props = defineProps({
  variant: { type: Object, required: true },
  campaignId: { type: Number, default: null },
  canEdit: { type: Boolean, default: false },
  aiEnabled: { type: Boolean, default: false },
});

const MAX_INSTRUCTION = 500;
const MAX_BODY = 3000;
const { t } = useI18n();
const campaignsStore = useGlintReachCampaignsStore();
const generations = useGlintReachGenerationsStore();

const isEditing = ref(false);
const isSaving = ref(false);
const draft = ref({ body: '', callToAction: '', hashtags: [] });
const showRewrite = ref(false);
const instruction = ref('');

const isReady = computed(() => props.variant.status === 'ready');
const target = computed(() => ({
  campaignId: props.campaignId,
  contentItemId: props.variant.contentItemId,
  variantId: props.variant.id,
}));
const latestOf = kind =>
  generations.latestFor({ kind, contentVariantId: props.variant.id });
const rewriteGen = computed(() => latestOf('rewrite'));
const suggestGen = computed(() => latestOf('suggestions'));
const regenerateGen = computed(() =>
  generations.latestFor({
    kind: 'variants',
    contentItemId: props.variant.contentItemId,
  })
);
const aiBusy = computed(
  () =>
    generations.isRequesting ||
    isActiveGeneration(rewriteGen.value) ||
    isActiveGeneration(regenerateGen.value)
);
const canUseAi = computed(
  () => props.aiEnabled && props.canEdit && !isReady.value
);
const instructionTooLong = computed(
  () => instruction.value.length > MAX_INSTRUCTION
);
const suggestions = computed(() =>
  suggestGen.value?.status === 'completed' ? suggestGen.value.result : null
);

const startEdit = () => {
  draft.value = {
    body: props.variant.body || '',
    callToAction: props.variant.callToAction || '',
    hashtags: [...(props.variant.hashtags || [])],
  };
  isEditing.value = true;
};

const save = async () => {
  isSaving.value = true;
  try {
    await campaignsStore.updateVariant(target.value, draft.value);
    isEditing.value = false;
    useAlert(t('GLINT_REACH.AI.VARIANT.SAVED'));
  } catch (error) {
    useAlert(error.message || t('GLINT_REACH.AI.VARIANT.SAVE_FAILED'));
  } finally {
    isSaving.value = false;
  }
};

const transition = async status => {
  try {
    await campaignsStore.transitionVariant(target.value, status);
  } catch (error) {
    useAlert(error.message || t('GLINT_REACH.AI.VARIANT.TRANSITION_FAILED'));
  }
};

const requestAi = async params => {
  try {
    await generations.request(params);
    useAlert(t('GLINT_REACH.AI.QUEUED_ALERT'));
    return true;
  } catch (error) {
    useAlert(error.message || t('GLINT_REACH.AI.REQUEST_FAILED'));
    return false;
  }
};

const regenerate = () =>
  requestAi({
    kind: 'variants',
    contentItemId: props.variant.contentItemId,
    platforms: [props.variant.platform],
  });

const rewrite = async () => {
  if (!instruction.value.trim() || instructionTooLong.value) return;
  const ok = await requestAi({
    kind: 'rewrite',
    contentVariantId: props.variant.id,
    instruction: instruction.value.trim(),
  });
  if (ok) {
    showRewrite.value = false;
    instruction.value = '';
  }
};

const suggest = () =>
  requestAi({ kind: 'suggestions', contentVariantId: props.variant.id });

const applyHashtag = async tag => {
  if (isEditing.value) {
    if (!draft.value.hashtags.includes(tag)) draft.value.hashtags.push(tag);
    return;
  }
  const hashtags = [...new Set([...(props.variant.hashtags || []), tag])];
  try {
    await campaignsStore.updateVariant(target.value, { hashtags });
  } catch (error) {
    useAlert(error.message || t('GLINT_REACH.AI.VARIANT.SAVE_FAILED'));
  }
};

const useCta = async cta => {
  if (isEditing.value) {
    draft.value.callToAction = cta;
    return;
  }
  try {
    await campaignsStore.updateVariant(target.value, { callToAction: cta });
  } catch (error) {
    useAlert(error.message || t('GLINT_REACH.AI.VARIANT.SAVE_FAILED'));
  }
};
</script>

<template>
  <li
    class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-1"
    :data-testid="`variant-${variant.id}`"
  >
    <div class="flex items-center justify-between gap-2 text-xs">
      <span class="font-medium text-n-slate-12">
        {{ t(`GLINT_REACH.PLATFORMS.${variant.platform.toUpperCase()}`) }}
      </span>
      <span class="text-n-slate-11">
        {{ t(`GLINT_REACH.STATUSES.${variant.status.toUpperCase()}`) }}
      </span>
    </div>

    <form
      v-if="isEditing"
      class="flex flex-col gap-2"
      data-testid="variant-editor"
      @submit.prevent="save"
    >
      <label class="flex flex-col gap-1 text-xs text-n-slate-11">
        {{ t('GLINT_REACH.AI.VARIANT.BODY') }}
        <textarea
          v-model="draft.body"
          rows="5"
          :maxlength="MAX_BODY"
          class="!mb-0 text-sm"
        />
      </label>
      <label class="flex flex-col gap-1 text-xs text-n-slate-11">
        {{ t('GLINT_REACH.AI.VARIANT.CTA') }}
        <input
          v-model="draft.callToAction"
          type="text"
          maxlength="255"
          class="!mb-0 text-sm"
        />
      </label>
      <ChipListInput
        v-model="draft.hashtags"
        :label="t('GLINT_REACH.AI.VARIANT.HASHTAGS')"
        :placeholder="t('GLINT_REACH.AI.VARIANT.HASHTAGS_PLACEHOLDER')"
        :max-items="30"
      />
      <div class="flex gap-2">
        <Button
          type="submit"
          size="xs"
          :label="t('GLINT_REACH.AI.VARIANT.SAVE')"
          :is-loading="isSaving"
          :disabled="isSaving"
        />
        <Button
          type="button"
          size="xs"
          variant="ghost"
          :label="t('GLINT_REACH.AI.VARIANT.CANCEL')"
          @click="isEditing = false"
        />
      </div>
    </form>
    <template v-else>
      <p
        class="mb-0 text-sm whitespace-pre-line break-words text-n-slate-12"
        data-testid="variant-body"
      >
        {{ variant.body || t('GLINT_REACH.FORM.NOT_SET') }}
      </p>
      <p v-if="variant.callToAction" class="mb-0 text-xs text-n-slate-11">
        {{ variant.callToAction }}
      </p>
      <p
        v-if="variant.hashtags.length"
        class="mb-0 text-xs break-words text-n-slate-11"
      >
        {{ variant.hashtags.map(tag => `#${tag}`).join(' ') }}
      </p>
    </template>

    <div v-if="canEdit && !isEditing" class="flex flex-wrap gap-1">
      <Button
        v-if="!isReady"
        size="xs"
        variant="ghost"
        icon="i-lucide-pencil"
        :label="t('GLINT_REACH.AI.VARIANT.EDIT')"
        @click="startEdit"
      />
      <Button
        size="xs"
        variant="ghost"
        :icon="isReady ? 'i-lucide-undo-2' : 'i-lucide-check'"
        :label="
          isReady
            ? t('GLINT_REACH.AI.VARIANT.MARK_DRAFT')
            : t('GLINT_REACH.AI.VARIANT.MARK_READY')
        "
        data-testid="variant-toggle-ready"
        @click="transition(isReady ? 'draft' : 'ready')"
      />
      <template v-if="aiEnabled">
        <Button
          size="xs"
          variant="ghost"
          icon="i-lucide-refresh-cw"
          data-testid="variant-regenerate"
          :label="t('GLINT_REACH.AI.VARIANT.REGENERATE')"
          :disabled="!canUseAi || aiBusy"
          @click="regenerate"
        />
        <Button
          size="xs"
          variant="ghost"
          icon="i-lucide-wand-sparkles"
          data-testid="variant-rewrite"
          :label="t('GLINT_REACH.AI.VARIANT.REWRITE')"
          :disabled="!canUseAi || aiBusy"
          @click="showRewrite = !showRewrite"
        />
        <Button
          size="xs"
          variant="ghost"
          icon="i-lucide-hash"
          data-testid="variant-suggest"
          :label="t('GLINT_REACH.AI.VARIANT.SUGGEST')"
          :disabled="generations.isRequesting || isActiveGeneration(suggestGen)"
          @click="suggest"
        />
      </template>
    </div>
    <p v-if="isReady && aiEnabled" class="mb-0 text-xs text-n-slate-10">
      {{ t('GLINT_REACH.AI.VARIANT.READY_HINT') }}
    </p>

    <form
      v-if="showRewrite && canUseAi"
      class="flex flex-col gap-1"
      data-testid="rewrite-form"
      @submit.prevent="rewrite"
    >
      <textarea
        v-model="instruction"
        rows="2"
        class="!mb-0 text-sm"
        :placeholder="t('GLINT_REACH.AI.VARIANT.REWRITE_PLACEHOLDER')"
        data-testid="rewrite-instruction"
      />
      <span
        v-if="instructionTooLong"
        class="text-xs text-n-ruby-11"
        role="alert"
      >
        {{
          t('GLINT_REACH.AI.VARIANT.INSTRUCTION_TOO_LONG', {
            max: MAX_INSTRUCTION,
          })
        }}
      </span>
      <Button
        type="submit"
        size="xs"
        class="w-fit"
        :label="t('GLINT_REACH.AI.VARIANT.REWRITE_SUBMIT')"
        :disabled="!instruction.trim() || instructionTooLong || aiBusy"
      />
    </form>

    <GenerationStatus :generation="rewriteGen" :can-retry="false" />
    <GenerationStatus
      :generation="suggestGen"
      :can-retry="aiEnabled"
      @retry="suggest"
    />

    <div
      v-if="suggestions && canEdit"
      class="flex flex-col gap-1"
      data-testid="variant-suggestions"
    >
      <span class="text-xs font-medium text-n-slate-11">
        {{ t('GLINT_REACH.AI.VARIANT.SUGGESTIONS') }}
      </span>
      <div class="flex flex-wrap gap-1">
        <button
          v-for="tag in suggestions.hashtags"
          :key="`h-${tag}`"
          type="button"
          class="px-2 py-0.5 text-xs rounded-full bg-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-3"
          :aria-label="t('GLINT_REACH.AI.VARIANT.APPLY_HASHTAG', { tag })"
          @click="applyHashtag(tag)"
        >
          #{{ tag }}
        </button>
        <button
          v-for="cta in suggestions.callsToAction"
          :key="`c-${cta}`"
          type="button"
          class="px-2 py-0.5 text-xs rounded-full bg-glint-reach/10 text-n-slate-12 hover:bg-glint-reach/20"
          :aria-label="t('GLINT_REACH.AI.VARIANT.USE_CTA', { cta })"
          @click="useCta(cta)"
        >
          {{ cta }}
        </button>
      </div>
    </div>
  </li>
</template>
