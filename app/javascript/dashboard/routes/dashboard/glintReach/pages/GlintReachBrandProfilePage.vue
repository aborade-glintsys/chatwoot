<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useGlintReachBrandProfileStore } from 'dashboard/stores/glintReach/brandProfile';
import BrandProfileForm from '../components/BrandProfileForm.vue';
import BrandProfileView from '../components/BrandProfileView.vue';
import GlintReachEmptyState from '../components/GlintReachEmptyState.vue';

const { t } = useI18n();
const store = useGlintReachBrandProfileStore();

const isEditing = ref(false);
const loadError = ref('');
const serverMessage = ref('');
const serverErrorFields = ref([]);

const profile = computed(() => store.profile);

const load = async () => {
  loadError.value = '';
  try {
    await store.fetch();
  } catch (error) {
    loadError.value = error.message || t('GLINT_REACH.ERRORS.LOAD_FAILED');
  }
};

const startEditing = () => {
  serverMessage.value = '';
  serverErrorFields.value = [];
  isEditing.value = true;
};

const onSubmit = async attributes => {
  serverMessage.value = '';
  serverErrorFields.value = [];
  try {
    await store.save(attributes);
    isEditing.value = false;
    useAlert(t('GLINT_REACH.BRAND_PROFILE.SAVED'));
  } catch (error) {
    serverMessage.value = error.message || t('GLINT_REACH.ERRORS.SAVE_FAILED');
    serverErrorFields.value = error.attributes || [];
  }
};

onMounted(load);
</script>

<template>
  <section class="flex flex-col w-full max-w-4xl gap-8 px-6 py-10 mx-auto">
    <header class="flex flex-wrap items-end justify-between gap-4">
      <div class="flex flex-col gap-2">
        <span class="w-10 h-1 rounded-full bg-glint-reach" />
        <h1 class="mb-0 text-2xl font-semibold text-n-slate-12">
          {{ t('GLINT_REACH.MODULES.BRAND_PROFILE.TITLE') }}
        </h1>
        <p class="max-w-2xl mb-0 text-sm text-n-slate-11">
          {{ t('GLINT_REACH.BRAND_PROFILE.DESCRIPTION') }}
        </p>
      </div>
      <Button
        v-if="profile && !isEditing"
        icon="i-lucide-pencil"
        variant="faded"
        :label="t('GLINT_REACH.FORM.EDIT')"
        data-testid="brand-profile-edit"
        @click="startEditing"
      />
    </header>

    <div
      v-if="store.uiFlags.isFetching && !store.hasLoaded"
      class="flex justify-center py-16"
    >
      <Spinner />
    </div>

    <GlintReachEmptyState
      v-else-if="loadError"
      icon="i-lucide-triangle-alert"
      :title="t('GLINT_REACH.ERRORS.LOAD_FAILED')"
      :description="loadError"
    >
      <Button :label="t('GLINT_REACH.FORM.RETRY')" @click="load" />
    </GlintReachEmptyState>

    <BrandProfileForm
      v-else-if="isEditing"
      :profile="profile"
      :is-saving="store.uiFlags.isSaving"
      :server-message="serverMessage"
      :server-error-fields="serverErrorFields"
      show-cancel
      @submit="onSubmit"
      @cancel="isEditing = false"
    />

    <GlintReachEmptyState
      v-else-if="!profile"
      icon="i-lucide-badge-check"
      :title="t('GLINT_REACH.BRAND_PROFILE.EMPTY_TITLE')"
      :description="t('GLINT_REACH.BRAND_PROFILE.EMPTY_DESCRIPTION')"
    >
      <Button
        icon="i-lucide-plus"
        :label="t('GLINT_REACH.BRAND_PROFILE.CREATE')"
        data-testid="brand-profile-create"
        @click="startEditing"
      />
    </GlintReachEmptyState>

    <article
      v-else
      class="flex flex-col gap-6 p-6 border rounded-2xl border-n-weak bg-n-solid-1"
    >
      <h2 class="mb-0 text-xl font-semibold break-words text-n-slate-12">
        {{ profile.name }}
      </h2>
      <BrandProfileView :profile="profile" />
    </article>
  </section>
</template>
