<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useGlintReachAssetsStore } from 'dashboard/stores/glintReach/assets';
import AssetFileButton from './AssetFileButton.vue';
import { MAX_ASSETS_PER_VARIANT } from '../helpers/assets';

// Reusable dialog to choose campaign assets (ordered by selection), with an
// inline upload. Emits `select` with the chosen asset IDs.
const props = defineProps({
  campaignId: { type: Number, required: true },
  max: { type: Number, default: MAX_ASSETS_PER_VARIANT },
  canUpload: { type: Boolean, default: true },
});
const emit = defineEmits(['select']);

const { t } = useI18n();
const store = useGlintReachAssetsStore();
const dialog = ref(null);
const selected = ref([]);
const errorMessage = ref('');

const isFull = computed(() => selected.value.length >= props.max);

// Opens with the current selection and refreshes previews (URLs expire).
const open = async (initialIds = []) => {
  selected.value = [...initialIds];
  errorMessage.value = '';
  dialog.value?.open();
  try {
    await store.load(props.campaignId);
  } catch (error) {
    errorMessage.value = error.message || t('GLINT_REACH.ERRORS.LOAD_FAILED');
  }
};

const toggle = id => {
  if (selected.value.includes(id)) {
    selected.value = selected.value.filter(value => value !== id);
  } else if (!isFull.value) {
    selected.value = [...selected.value, id];
  }
};

const upload = async file => {
  errorMessage.value = '';
  try {
    const asset = await store.upload(file);
    if (!isFull.value) selected.value = [...selected.value, asset.id];
  } catch (error) {
    errorMessage.value = error.message || t('GLINT_REACH.ASSETS.ERRORS.FAILED');
  }
};

const confirm = () => {
  emit('select', [...selected.value]);
  dialog.value?.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="3xl"
    overflow-y-auto
    :title="t('GLINT_REACH.ASSETS.PICKER_TITLE')"
    :description="t('GLINT_REACH.ASSETS.PICKER_DESCRIPTION', { max })"
    :confirm-button-label="t('GLINT_REACH.ASSETS.PICKER_CONFIRM')"
    @confirm="confirm"
  >
    <div class="flex flex-col gap-3" data-testid="asset-picker">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <span class="text-xs text-n-slate-11">
          {{
            t('GLINT_REACH.ASSETS.SELECTED', { count: selected.length, max })
          }}
        </span>
        <AssetFileButton
          v-if="canUpload"
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
      >
        {{ errorMessage }}
      </p>
      <div
        v-if="store.uiFlags.isFetching && !store.records.length"
        class="flex justify-center py-8"
      >
        <Spinner />
      </div>
      <p
        v-else-if="!store.records.length"
        class="py-8 mb-0 text-sm text-center text-n-slate-11"
      >
        {{ t('GLINT_REACH.ASSETS.EMPTY') }}
      </p>
      <ul v-else class="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <li v-for="asset in store.records" :key="asset.id">
          <button
            type="button"
            class="relative block w-full overflow-hidden border-2 rounded-lg aspect-square bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand disabled:opacity-50"
            :class="
              selected.includes(asset.id)
                ? 'border-glint-reach'
                : 'border-transparent'
            "
            :aria-pressed="selected.includes(asset.id)"
            :aria-label="asset.altText || asset.filename"
            :disabled="isFull && !selected.includes(asset.id)"
            :data-testid="`picker-asset-${asset.id}`"
            @click="toggle(asset.id)"
          >
            <img
              :src="asset.thumbnailUrl"
              :alt="asset.altText || ''"
              loading="lazy"
              class="object-cover w-full h-full"
            />
            <span
              v-if="selected.includes(asset.id)"
              class="absolute flex items-center justify-center text-xs font-semibold text-white rounded-full top-1 ltr:right-1 rtl:left-1 size-5 bg-glint-reach"
            >
              {{ selected.indexOf(asset.id) + 1 }}
            </span>
          </button>
        </li>
      </ul>
    </div>
  </Dialog>
</template>
