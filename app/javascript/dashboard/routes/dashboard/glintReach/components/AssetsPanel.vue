<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useGlintReachAssetsStore } from 'dashboard/stores/glintReach/assets';
import AssetFileButton from './AssetFileButton.vue';
import { ASSET_MAX_ALT_TEXT, formatBytes } from '../helpers/assets';

// Upload, preview, alt text, replace and remove for a campaign's assets.
const props = defineProps({
  campaignId: { type: Number, required: true },
  canEdit: { type: Boolean, default: false },
});
const emit = defineEmits(['changed']);

const { t } = useI18n();
const store = useGlintReachAssetsStore();
const loadError = ref('');
const errorMessage = ref('');
const editingAltId = ref(null);
const altDraft = ref('');
const pendingRemove = ref(null);
const removeDialog = ref(null);

const load = async () => {
  loadError.value = '';
  try {
    await store.load(props.campaignId);
  } catch (error) {
    loadError.value = error.message || t('GLINT_REACH.ERRORS.LOAD_FAILED');
  }
};

const run = async (action, successKey) => {
  errorMessage.value = '';
  try {
    await action();
    if (successKey) useAlert(t(successKey));
    emit('changed');
  } catch (error) {
    errorMessage.value = error.message || t('GLINT_REACH.ASSETS.ERRORS.FAILED');
  }
};

const upload = file =>
  run(() => store.upload(file), 'GLINT_REACH.ASSETS.UPLOADED');
const replace = (asset, file) =>
  run(() => store.update(asset.id, { file }), 'GLINT_REACH.ASSETS.REPLACED');

const startAlt = asset => {
  editingAltId.value = asset.id;
  altDraft.value = asset.altText || '';
};
const saveAlt = asset =>
  run(async () => {
    await store.update(asset.id, { altText: altDraft.value });
    editingAltId.value = null;
  }, 'GLINT_REACH.ASSETS.ALT_SAVED');

const askRemove = asset => {
  pendingRemove.value = asset;
  removeDialog.value?.open();
};
const confirmRemove = async () => {
  const asset = pendingRemove.value;
  removeDialog.value?.close();
  if (asset)
    await run(() => store.remove(asset.id), 'GLINT_REACH.ASSETS.REMOVED');
  pendingRemove.value = null;
};

watch(() => props.campaignId, load, { immediate: true });
</script>

<template>
  <section class="flex flex-col gap-3" data-testid="assets-panel">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div class="flex flex-col">
        <h2 class="mb-0 text-base font-medium text-n-slate-12">
          {{ t('GLINT_REACH.ASSETS.TITLE') }}
        </h2>
        <p class="mb-0 text-xs text-n-slate-11">
          {{ t('GLINT_REACH.ASSETS.HINT') }}
        </p>
      </div>
      <AssetFileButton
        v-if="canEdit"
        :label="t('GLINT_REACH.ASSETS.UPLOAD')"
        :is-loading="store.uiFlags.isUploading"
        @select="upload"
        @invalid="errorMessage = $event"
      />
    </div>

    <p
      v-if="errorMessage"
      class="px-3 py-2 mb-0 text-sm rounded-lg bg-n-ruby-3 text-n-ruby-11"
      role="alert"
      data-testid="assets-error"
    >
      {{ errorMessage }}
    </p>

    <div
      v-if="store.uiFlags.isFetching && !store.records.length"
      class="flex justify-center py-6"
    >
      <Spinner />
    </div>
    <div
      v-else-if="loadError"
      class="flex items-center gap-2 text-sm text-n-ruby-11"
    >
      {{ loadError }}
      <Button
        size="xs"
        variant="ghost"
        :label="t('GLINT_REACH.FORM.RETRY')"
        @click="load"
      />
    </div>
    <p
      v-else-if="!store.records.length"
      class="px-4 py-6 mb-0 text-sm text-center border border-dashed rounded-xl border-n-weak text-n-slate-11"
      data-testid="assets-empty"
    >
      {{ t('GLINT_REACH.ASSETS.EMPTY') }}
    </p>
    <ul v-else class="grid gap-3 sm:grid-cols-2">
      <li
        v-for="asset in store.records"
        :key="asset.id"
        class="flex flex-col gap-2 p-2 border rounded-xl border-n-weak bg-n-solid-1"
        :data-testid="`asset-${asset.id}`"
      >
        <a
          :href="asset.url"
          target="_blank"
          rel="noopener noreferrer"
          class="block overflow-hidden rounded-lg bg-n-alpha-2 aspect-video"
        >
          <img
            :src="asset.thumbnailUrl"
            :alt="asset.altText || ''"
            loading="lazy"
            class="object-contain w-full h-full"
          />
        </a>
        <div class="flex flex-col text-xs text-n-slate-11">
          <span class="font-medium truncate text-n-slate-12">
            {{ asset.filename }}
          </span>
          <span>
            {{
              t('GLINT_REACH.ASSETS.META', {
                width: asset.width,
                height: asset.height,
                size: formatBytes(asset.byteSize),
              })
            }}
          </span>
        </div>
        <form
          v-if="editingAltId === asset.id"
          class="flex flex-col gap-1"
          @submit.prevent="saveAlt(asset)"
        >
          <label class="flex flex-col gap-1 text-xs text-n-slate-11">
            {{ t('GLINT_REACH.ASSETS.ALT_TEXT') }}
            <textarea
              v-model="altDraft"
              rows="2"
              :maxlength="ASSET_MAX_ALT_TEXT"
              class="!mb-0 text-sm"
              data-testid="asset-alt-input"
            />
          </label>
          <div class="flex gap-1">
            <Button
              type="submit"
              size="xs"
              :label="t('GLINT_REACH.FORM.SAVE')"
              :is-loading="store.uiFlags.savingId === asset.id"
            />
            <Button
              type="button"
              size="xs"
              variant="ghost"
              :label="t('GLINT_REACH.FORM.CANCEL')"
              @click="editingAltId = null"
            />
          </div>
        </form>
        <p
          v-else
          class="mb-0 text-xs break-words"
          :class="asset.altText ? 'text-n-slate-12' : 'text-n-amber-11'"
        >
          {{ asset.altText || t('GLINT_REACH.ASSETS.NO_ALT_TEXT') }}
        </p>
        <div
          v-if="canEdit && editingAltId !== asset.id"
          class="flex flex-wrap gap-1"
        >
          <Button
            size="xs"
            variant="ghost"
            icon="i-lucide-text"
            :label="t('GLINT_REACH.ASSETS.EDIT_ALT')"
            @click="startAlt(asset)"
          />
          <AssetFileButton
            size="xs"
            variant="ghost"
            icon="i-lucide-replace"
            :label="t('GLINT_REACH.ASSETS.REPLACE')"
            :is-loading="store.uiFlags.savingId === asset.id"
            @select="file => replace(asset, file)"
            @invalid="errorMessage = $event"
          />
          <Button
            size="xs"
            variant="ghost"
            color="ruby"
            icon="i-lucide-trash-2"
            :label="t('GLINT_REACH.ASSETS.REMOVE')"
            :data-testid="`asset-remove-${asset.id}`"
            @click="askRemove(asset)"
          />
        </div>
      </li>
    </ul>

    <Dialog
      ref="removeDialog"
      type="alert"
      :title="t('GLINT_REACH.ASSETS.REMOVE_TITLE')"
      :description="t('GLINT_REACH.ASSETS.REMOVE_DESCRIPTION')"
      :confirm-button-label="t('GLINT_REACH.ASSETS.REMOVE')"
      @confirm="confirmRemove"
    />
  </section>
</template>
