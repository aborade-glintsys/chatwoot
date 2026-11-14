<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import { ASSET_ACCEPT, precheckAssetFile } from '../helpers/assets';

// Opens a file chooser and emits a pre-checked file, or `invalid` with a message.
defineProps({
  label: { type: String, required: true },
  icon: { type: String, default: 'i-lucide-upload' },
  isLoading: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  size: { type: String, default: 'sm' },
  variant: { type: String, default: 'faded' },
});
const emit = defineEmits(['select', 'invalid']);
const { t } = useI18n();
const input = ref(null);

const onChange = event => {
  const [file] = event.target.files || [];
  event.target.value = '';
  if (!file) return;
  const problem = precheckAssetFile(file);
  if (problem) emit('invalid', t(problem));
  else emit('select', file);
};
</script>

<template>
  <span class="inline-flex">
    <input
      ref="input"
      type="file"
      class="hidden"
      :accept="ASSET_ACCEPT"
      data-testid="asset-file-input"
      @change="onChange"
    />
    <Button
      type="button"
      :size="size"
      :variant="variant"
      :icon="icon"
      :label="label"
      :is-loading="isLoading"
      :disabled="disabled || isLoading"
      @click="input?.click()"
    />
  </span>
</template>
