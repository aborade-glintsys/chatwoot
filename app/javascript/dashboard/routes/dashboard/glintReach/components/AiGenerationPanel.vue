<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  useGlintReachGenerationsStore,
  isActiveGeneration,
} from 'dashboard/stores/glintReach/generations';
import GenerationStatus from './GenerationStatus.vue';

// Campaign-level AI actions: strategy, content plan and single item.
const props = defineProps({
  campaign: { type: Object, required: true },
  enabled: { type: Boolean, default: false },
});

const { t } = useI18n();
const store = useGlintReachGenerationsStore();
const MAX_PLAN_ITEMS = 10;
const planCount = ref(5);

const strategy = computed(() => props.campaign.strategy);
const latest = kind => store.latestFor({ kind });
const busy = kind => isActiveGeneration(latest(kind));

const generate = async params => {
  try {
    await store.request(params);
    useAlert(t('GLINT_REACH.AI.QUEUED_ALERT'));
  } catch (error) {
    useAlert(error.message || t('GLINT_REACH.AI.REQUEST_FAILED'));
  }
};

const generatePlan = () =>
  generate({
    kind: 'content_plan',
    count: Math.min(Math.max(Number(planCount.value) || 1, 1), MAX_PLAN_ITEMS),
  });
</script>

<template>
  <section
    class="flex flex-col gap-4 p-4 border rounded-xl border-n-weak bg-n-solid-1"
    data-testid="ai-generation-panel"
  >
    <header class="flex flex-col gap-1">
      <h2 class="mb-0 text-base font-medium text-n-slate-12">
        {{ t('GLINT_REACH.AI.TITLE') }}
      </h2>
      <p class="mb-0 text-xs text-n-slate-11">
        {{ t('GLINT_REACH.AI.DESCRIPTION') }}
      </p>
    </header>

    <div class="flex flex-col gap-2">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h3 class="mb-0 text-sm font-medium text-n-slate-12">
          {{ t('GLINT_REACH.AI.STRATEGY_TITLE') }}
        </h3>
        <Button
          size="sm"
          variant="faded"
          icon="i-lucide-sparkles"
          data-testid="generate-strategy"
          :label="
            strategy
              ? t('GLINT_REACH.AI.REGENERATE_STRATEGY')
              : t('GLINT_REACH.AI.GENERATE_STRATEGY')
          "
          :disabled="!enabled || busy('strategy') || store.isRequesting"
          @click="generate({ kind: 'strategy' })"
        />
      </div>
      <GenerationStatus
        :generation="latest('strategy')"
        :can-retry="enabled"
        @retry="generate({ kind: 'strategy' })"
      />
      <p v-if="!strategy" class="mb-0 text-xs text-n-slate-10">
        {{ t('GLINT_REACH.AI.STRATEGY_EMPTY') }}
      </p>
      <dl
        v-else
        class="flex flex-col gap-2 text-sm text-n-slate-12"
        data-testid="campaign-strategy"
      >
        <dt class="text-xs font-medium text-n-slate-11">
          {{ t('GLINT_REACH.AI.POSITIONING') }}
        </dt>
        <dd class="m-0 break-words">{{ strategy.positioning }}</dd>
        <dt class="text-xs font-medium text-n-slate-11">
          {{ t('GLINT_REACH.AI.KEY_MESSAGES') }}
        </dt>
        <dd class="m-0">
          <ul class="pl-4 m-0 list-disc">
            <li
              v-for="message in strategy.keyMessages"
              :key="message"
              class="break-words"
            >
              {{ message }}
            </li>
          </ul>
        </dd>
        <dt class="text-xs font-medium text-n-slate-11">
          {{ t('GLINT_REACH.AI.PILLARS') }}
        </dt>
        <dd class="m-0">
          <ul class="flex flex-col gap-1 m-0">
            <li
              v-for="pillar in strategy.contentPillars"
              :key="pillar.name"
              class="break-words"
            >
              <span class="font-medium">{{ pillar.name }}</span>
              — {{ pillar.description }}
            </li>
          </ul>
        </dd>
        <template v-if="strategy.channelApproach?.length">
          <dt class="text-xs font-medium text-n-slate-11">
            {{ t('GLINT_REACH.AI.CHANNEL_APPROACH') }}
          </dt>
          <dd class="m-0">
            <ul class="flex flex-col gap-1 m-0">
              <li
                v-for="entry in strategy.channelApproach"
                :key="entry.platform"
                class="break-words"
              >
                <span class="font-medium">
                  {{
                    t(`GLINT_REACH.PLATFORMS.${entry.platform.toUpperCase()}`)
                  }}
                </span>
                — {{ entry.approach }}
              </li>
            </ul>
          </dd>
        </template>
      </dl>
    </div>

    <div class="flex flex-col gap-2 pt-3 border-t border-n-weak">
      <h3 class="mb-0 text-sm font-medium text-n-slate-12">
        {{ t('GLINT_REACH.AI.PLAN_TITLE') }}
      </h3>
      <div class="flex flex-wrap items-end gap-2">
        <label class="flex flex-col gap-1 text-xs text-n-slate-11">
          {{ t('GLINT_REACH.AI.PLAN_COUNT') }}
          <input
            v-model.number="planCount"
            type="number"
            min="1"
            :max="MAX_PLAN_ITEMS"
            class="w-20 !mb-0"
            data-testid="plan-count"
            :disabled="!enabled"
          />
        </label>
        <Button
          size="sm"
          variant="faded"
          icon="i-lucide-list-plus"
          data-testid="generate-plan"
          :label="t('GLINT_REACH.AI.GENERATE_PLAN')"
          :disabled="!enabled || busy('content_plan') || store.isRequesting"
          @click="generatePlan"
        />
        <Button
          size="sm"
          variant="ghost"
          icon="i-lucide-plus"
          data-testid="generate-item"
          :label="t('GLINT_REACH.AI.ADD_ITEM')"
          :disabled="!enabled || busy('content_item') || store.isRequesting"
          @click="generate({ kind: 'content_item' })"
        />
      </div>
      <GenerationStatus
        :generation="latest('content_plan')"
        :can-retry="enabled"
        @retry="generatePlan"
      />
      <GenerationStatus
        :generation="latest('content_item')"
        :can-retry="enabled"
        @retry="generate({ kind: 'content_item' })"
      />
    </div>
  </section>
</template>
