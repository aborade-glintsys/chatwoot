<script setup>
defineProps({
  icon: { type: String, default: 'i-lucide-sparkles' },
  title: { type: String, required: true },
  description: { type: String, default: '' },
});
</script>

<template>
  <section
    class="relative flex flex-col items-center gap-4 px-6 py-16 overflow-hidden text-center border rounded-2xl border-n-weak bg-n-solid-1"
    data-testid="glint-reach-empty-state"
  >
    <div
      class="absolute inset-x-0 top-0 h-32 pointer-events-none bg-gradient-to-b from-glint-reach/10 to-transparent"
      aria-hidden="true"
    />
    <span
      class="relative flex items-center justify-center rounded-2xl size-12 bg-glint-reach/10 text-glint-reach"
      aria-hidden="true"
    >
      <span class="size-6" :class="icon" />
    </span>
    <div class="relative flex flex-col gap-2">
      <h2 class="mb-0 text-lg font-semibold text-n-slate-12">{{ title }}</h2>
      <p v-if="description" class="max-w-lg mb-0 text-sm text-n-slate-11">
        {{ description }}
      </p>
    </div>
    <div
      v-if="$slots.default"
      class="relative flex flex-wrap justify-center gap-3"
    >
      <slot />
    </div>
  </section>
</template>
