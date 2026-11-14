<script setup>
import { ref, computed, getCurrentInstance } from 'vue';
import { useI18n } from 'vue-i18n';

// Editable list of short strings rendered as removable chips.
// With `options`, values are picked from a <select>; otherwise typed and added with Enter.
const props = defineProps({
  label: { type: String, required: true },
  placeholder: { type: String, default: '' },
  options: { type: Array, default: () => [] },
  maxItems: { type: Number, default: 20 },
  maxLength: { type: Number, default: 100 },
  message: { type: String, default: '' },
  messageType: { type: String, default: 'info' },
  disabled: { type: Boolean, default: false },
});

const modelValue = defineModel({ type: Array, default: () => [] });

const { t } = useI18n();
const { uid } = getCurrentInstance();
const inputId = `chip-list-${uid}`;
const messageId = `${inputId}-message`;
const draft = ref('');

const labelFor = value =>
  props.options.find(option => option.value === value)?.label || value;

const availableOptions = computed(() =>
  props.options.filter(option => !modelValue.value.includes(option.value))
);
const isFull = computed(() => modelValue.value.length >= props.maxItems);

const add = rawValue => {
  const value = (rawValue || '').trim().replace(/\s+/g, ' ');
  draft.value = '';
  if (!value || isFull.value || modelValue.value.includes(value)) return;
  modelValue.value = [...modelValue.value, value];
};

const remove = value => {
  modelValue.value = modelValue.value.filter(item => item !== value);
};

const onSelect = event => {
  add(event.target.value);
  event.target.value = '';
};
</script>

<template>
  <div class="flex flex-col gap-1 min-w-0">
    <label :for="inputId" class="mb-0.5 text-heading-3 text-n-slate-12">
      {{ label }}
    </label>
    <ul
      v-if="modelValue.length"
      class="flex flex-wrap gap-2 mb-1"
      :aria-label="label"
    >
      <li
        v-for="item in modelValue"
        :key="item"
        class="inline-flex items-center gap-1 py-1 ltr:pl-2.5 ltr:pr-1 rtl:pr-2.5 rtl:pl-1 text-sm rounded-full bg-n-alpha-2 text-n-slate-12"
      >
        <span class="break-all">{{ labelFor(item) }}</span>
        <button
          v-if="!disabled"
          type="button"
          class="flex items-center justify-center rounded-full size-5 text-n-slate-11 hover:bg-n-alpha-3 hover:text-n-slate-12"
          :aria-label="
            t('GLINT_REACH.FORM.REMOVE_ITEM', { item: labelFor(item) })
          "
          @click="remove(item)"
        >
          <span class="i-lucide-x size-3.5" />
        </button>
      </li>
    </ul>
    <select
      v-if="options.length"
      :id="inputId"
      :disabled="disabled || isFull"
      :aria-describedby="message ? messageId : undefined"
      class="w-full max-w-xs px-3 py-2 text-sm rounded-lg outline outline-1 -outline-offset-1 outline-n-weak bg-n-surface-1 !mb-0 disabled:opacity-50"
      @change="onSelect"
    >
      <option value="">{{ placeholder }}</option>
      <option
        v-for="option in availableOptions"
        :key="option.value"
        :value="option.value"
      >
        {{ option.label }}
      </option>
    </select>
    <input
      v-else
      :id="inputId"
      v-model="draft"
      type="text"
      :maxlength="maxLength"
      :placeholder="placeholder"
      :disabled="disabled || isFull"
      :aria-describedby="message ? messageId : undefined"
      enterkeyhint="done"
      class="block w-full h-10 px-3 text-sm rounded-lg reset-base !mb-0 outline outline-1 -outline-offset-1 outline-n-weak bg-n-alpha-black2 text-n-slate-12 placeholder:text-n-slate-10 disabled:opacity-50"
      @keydown.enter.prevent="add(draft)"
      @blur="add(draft)"
    />
    <p
      v-if="message"
      :id="messageId"
      class="mt-1 mb-0 text-label-small"
      :class="messageType === 'error' ? 'text-n-ruby-9' : 'text-n-slate-11'"
      :role="messageType === 'error' ? 'alert' : undefined"
    >
      {{ message }}
    </p>
  </div>
</template>
