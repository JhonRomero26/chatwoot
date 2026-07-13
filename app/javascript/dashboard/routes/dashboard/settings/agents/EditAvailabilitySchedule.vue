<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import AgentAPI from 'dashboard/api/agents';
import {
  buildAvailabilityPayload,
  buildWeeklySchedule,
  DAY_KEYS,
  validateDayRanges,
} from './availabilitySchedule';
import {
  DEFAULT_TIMEZONE,
  timeZoneOptions,
} from '../inbox/helpers/businessHour';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const isLoading = ref(false);
const isSaving = ref(false);
const timezone = ref(DEFAULT_TIMEZONE.value);
const weeklySchedule = ref(buildWeeklySchedule());

const timezoneOptions = computed(() => [...timeZoneOptions()]);
const pageTitle = computed(() =>
  t('AGENT_MGMT.SCHEDULE.TITLE', { name: props.name })
);
const pageDescription = computed(() => t('AGENT_MGMT.SCHEDULE.DESCRIPTION'));

const dayErrors = computed(() =>
  weeklySchedule.value.map(day => validateDayRanges(day.ranges))
);

const hasErrors = computed(() => dayErrors.value.some(Boolean));

const errorMessage = errorKey => {
  if (!errorKey) return '';

  if (errorKey === 'MISSING_TIME') {
    return t('AGENT_MGMT.SCHEDULE.ERRORS.MISSING_TIME');
  }

  if (errorKey === 'INVALID_ORDER') {
    return t('AGENT_MGMT.SCHEDULE.ERRORS.INVALID_ORDER');
  }

  return t('AGENT_MGMT.SCHEDULE.ERRORS.OVERLAP');
};

const dayLabel = dayOfWeek => {
  const dayKey = DAY_KEYS[dayOfWeek];

  if (dayKey === 'SUNDAY') return t('AGENT_MGMT.SCHEDULE.DAYS.SUNDAY');
  if (dayKey === 'MONDAY') return t('AGENT_MGMT.SCHEDULE.DAYS.MONDAY');
  if (dayKey === 'TUESDAY') return t('AGENT_MGMT.SCHEDULE.DAYS.TUESDAY');
  if (dayKey === 'WEDNESDAY') return t('AGENT_MGMT.SCHEDULE.DAYS.WEDNESDAY');
  if (dayKey === 'THURSDAY') return t('AGENT_MGMT.SCHEDULE.DAYS.THURSDAY');
  if (dayKey === 'FRIDAY') return t('AGENT_MGMT.SCHEDULE.DAYS.FRIDAY');

  return t('AGENT_MGMT.SCHEDULE.DAYS.SATURDAY');
};

const loadSchedule = async () => {
  isLoading.value = true;
  try {
    const { data } = await AgentAPI.getAvailabilitySchedule(props.id);
    timezone.value = data.timezone || DEFAULT_TIMEZONE.value;
    weeklySchedule.value = buildWeeklySchedule(data.weekly_schedule);
  } catch (error) {
    useAlert(t('AGENT_MGMT.SCHEDULE.API.LOAD_ERROR'));
    emit('close');
  } finally {
    isLoading.value = false;
  }
};

const addRange = dayIndex => {
  weeklySchedule.value[dayIndex].ranges.push({
    startTime: '',
    endTime: '',
  });
};

const removeRange = (dayIndex, rangeIndex) => {
  weeklySchedule.value[dayIndex].ranges.splice(rangeIndex, 1);
};

const updateRange = (dayIndex, rangeIndex, field, value) => {
  weeklySchedule.value[dayIndex].ranges[rangeIndex][field] = value;
};

const saveSchedule = async () => {
  if (hasErrors.value) return;

  isSaving.value = true;
  try {
    await AgentAPI.updateAvailabilitySchedule(
      props.id,
      buildAvailabilityPayload({
        timezone: timezone.value,
        weeklySchedule: weeklySchedule.value,
      })
    );
    useAlert(t('AGENT_MGMT.SCHEDULE.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    useAlert(t('AGENT_MGMT.SCHEDULE.API.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};

onMounted(loadSchedule);
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="pageTitle"
      :header-content="pageDescription"
    />

    <div
      v-if="isLoading"
      class="px-6 py-8 text-center text-body-main text-n-slate-11"
    >
      {{ $t('AGENT_MGMT.SCHEDULE.LOADING') }}
    </div>

    <form v-else class="flex flex-col gap-6" @submit.prevent="saveSchedule">
      <div class="px-6">
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ $t('AGENT_MGMT.SCHEDULE.TIMEZONE_LABEL') }}
        </label>
        <ComboBox
          v-model="timezone"
          :options="timezoneOptions"
          :placeholder="$t('AGENT_MGMT.SCHEDULE.TIMEZONE_PLACEHOLDER')"
        />
      </div>

      <div class="px-6 pb-2 space-y-4">
        <div
          v-for="(day, dayIndex) in weeklySchedule"
          :key="day.dayOfWeek"
          class="rounded-xl border border-n-weak p-4"
        >
          <div class="flex items-start justify-between gap-3 mb-3">
            <div>
              <h3 class="text-sm font-medium text-n-slate-12">
                {{ dayLabel(day.dayOfWeek) }}
              </h3>
              <p class="text-xs text-n-slate-11 mt-1">
                {{
                  day.ranges.length
                    ? $t('AGENT_MGMT.SCHEDULE.DAY_HELP')
                    : $t('AGENT_MGMT.SCHEDULE.UNAVAILABLE')
                }}
              </p>
            </div>
            <Button
              type="button"
              sm
              slate
              :label="$t('AGENT_MGMT.SCHEDULE.ADD_RANGE')"
              @click="addRange(dayIndex)"
            />
          </div>

          <div v-if="day.ranges.length" class="space-y-3">
            <div
              v-for="(range, rangeIndex) in day.ranges"
              :key="`${day.dayOfWeek}-${rangeIndex}`"
              class="grid grid-cols-1 md:grid-cols-[1fr_1fr_auto] gap-3 items-end"
            >
              <label class="block">
                <span class="sr-only">
                  {{
                    $t('AGENT_MGMT.SCHEDULE.FROM_LABEL', {
                      day: dayLabel(day.dayOfWeek),
                      index: rangeIndex + 1,
                    })
                  }}
                </span>
                <span class="block text-xs text-n-slate-11 mb-1">
                  {{ $t('AGENT_MGMT.SCHEDULE.FROM') }}
                </span>
                <input
                  :value="range.startTime"
                  type="time"
                  class="w-full"
                  @input="
                    event =>
                      updateRange(
                        dayIndex,
                        rangeIndex,
                        'startTime',
                        event.target.value
                      )
                  "
                />
              </label>

              <label class="block">
                <span class="sr-only">
                  {{
                    $t('AGENT_MGMT.SCHEDULE.TO_LABEL', {
                      day: dayLabel(day.dayOfWeek),
                      index: rangeIndex + 1,
                    })
                  }}
                </span>
                <span class="block text-xs text-n-slate-11 mb-1">
                  {{ $t('AGENT_MGMT.SCHEDULE.TO') }}
                </span>
                <input
                  :value="range.endTime"
                  type="time"
                  class="w-full"
                  @input="
                    event =>
                      updateRange(
                        dayIndex,
                        rangeIndex,
                        'endTime',
                        event.target.value
                      )
                  "
                />
              </label>

              <Button
                type="button"
                sm
                slate
                icon="i-lucide-trash-2"
                :label="$t('AGENT_MGMT.SCHEDULE.REMOVE_RANGE')"
                @click="removeRange(dayIndex, rangeIndex)"
              />
            </div>
          </div>

          <p v-if="dayErrors[dayIndex]" class="text-sm text-n-ruby-11 mt-3">
            {{ errorMessage(dayErrors[dayIndex]) }}
          </p>
        </div>
      </div>

      <div
        class="flex justify-end items-center gap-2 px-6 py-4 border-t border-n-weak"
      >
        <Button
          faded
          slate
          type="button"
          :label="$t('AGENT_MGMT.SCHEDULE.CANCEL')"
          @click="emit('close')"
        />
        <Button
          type="submit"
          :label="$t('AGENT_MGMT.SCHEDULE.SAVE')"
          :disabled="hasErrors || isSaving"
          :is-loading="isSaving"
        />
      </div>
    </form>
  </div>
</template>
