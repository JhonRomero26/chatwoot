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
  groupScheduleByRange,
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

// New-entry form state (day multi-select + a single time range).
const selectedDays = ref([]);
const startHour = ref('09');
const startMinute = ref('00');
const endHour = ref('17');
const endMinute = ref('00');
const addEntryError = ref('');

// Pills render Monday -> Sunday to match the reference design, while the
// underlying dayOfWeek indices stay Sunday-first (0-6) to match the API.
const DISPLAY_DAY_ORDER = [1, 2, 3, 4, 5, 6, 0];

const hourOptions = Array.from({ length: 24 }, (_, hour) =>
  `${hour}`.padStart(2, '0')
);
// ponytail: 15-minute steps keep the dropdown short; add finer granularity
// if agents ever need minute-level precision.
const minuteOptions = ['00', '15', '30', '45'];

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

  if (errorKey === 'SELECT_DAYS') {
    return t('AGENT_MGMT.SCHEDULE.ERRORS.SELECT_DAYS');
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

// ponytail: derives the pill abbreviation from the translated day name
// instead of adding a parallel *_SHORT key per locale.
const shortDayLabel = dayOfWeek => dayLabel(dayOfWeek).slice(0, 3);

const orderDays = days =>
  [...days].sort(
    (left, right) =>
      DISPLAY_DAY_ORDER.indexOf(left) - DISPLAY_DAY_ORDER.indexOf(right)
  );

const isDaySelected = dayOfWeek => selectedDays.value.includes(dayOfWeek);

const toggleDay = dayOfWeek => {
  addEntryError.value = '';
  selectedDays.value = isDaySelected(dayOfWeek)
    ? selectedDays.value.filter(day => day !== dayOfWeek)
    : [...selectedDays.value, dayOfWeek];
};

const startTime = computed(() => `${startHour.value}:${startMinute.value}`);
const endTime = computed(() => `${endHour.value}:${endMinute.value}`);

const previewDaysText = computed(() =>
  orderDays(selectedDays.value).map(dayLabel).join(', ')
);

// Entries are derived from weeklySchedule (the source of truth used for
// validation and the save payload) instead of tracked separately, so there's
// nothing to keep in sync.
const scheduleGroups = computed(() =>
  groupScheduleByRange(weeklySchedule.value)
);

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

const addSchedule = () => {
  if (!selectedDays.value.length) {
    addEntryError.value = 'SELECT_DAYS';
    return;
  }

  const newRange = { startTime: startTime.value, endTime: endTime.value };
  const blockingError = selectedDays.value
    .map(dayOfWeek =>
      validateDayRanges([...weeklySchedule.value[dayOfWeek].ranges, newRange])
    )
    .find(Boolean);

  if (blockingError) {
    addEntryError.value = blockingError;
    return;
  }

  addEntryError.value = '';
  selectedDays.value.forEach(dayOfWeek => {
    weeklySchedule.value[dayOfWeek].ranges.push({ ...newRange });
  });
  selectedDays.value = [];
};

const removeEntry = group => {
  group.days.forEach(dayOfWeek => {
    const ranges = weeklySchedule.value[dayOfWeek].ranges;
    const index = ranges.findIndex(
      range =>
        range.startTime === group.startTime && range.endTime === group.endTime
    );
    if (index !== -1) ranges.splice(index, 1);
  });
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
      <label class="block px-6" for="agent-schedule-timezone">
        <span class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ $t('AGENT_MGMT.SCHEDULE.TIMEZONE_LABEL') }}
        </span>
        <ComboBox
          id="agent-schedule-timezone"
          v-model="timezone"
          :options="timezoneOptions"
          :placeholder="$t('AGENT_MGMT.SCHEDULE.TIMEZONE_PLACEHOLDER')"
        />
      </label>

      <div class="px-6 pb-2 space-y-4">
        <div class="rounded-xl border border-n-weak p-4 space-y-4">
          <h3 class="text-sm font-medium text-n-slate-12">
            {{ $t('AGENT_MGMT.SCHEDULE.NEW_ENTRY_TITLE') }}
          </h3>

          <div>
            <span class="block text-xs text-n-slate-11 mb-2">
              {{ $t('AGENT_MGMT.SCHEDULE.SELECT_DAYS_LABEL') }}
            </span>
            <div class="flex flex-wrap gap-2">
              <Button
                v-for="day in DISPLAY_DAY_ORDER"
                :key="day"
                type="button"
                sm
                class="rounded-full"
                :variant="isDaySelected(day) ? 'faded' : 'outline'"
                :color="isDaySelected(day) ? 'blue' : 'slate'"
                :label="shortDayLabel(day)"
                :aria-label="dayLabel(day)"
                :aria-pressed="isDaySelected(day)"
                @click="toggleDay(day)"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <span class="block text-xs text-n-slate-11 mb-1">
                {{ $t('AGENT_MGMT.SCHEDULE.FROM') }}
              </span>
              <div class="flex gap-2">
                <label class="flex-1">
                  <span class="sr-only">
                    {{ $t('AGENT_MGMT.SCHEDULE.FROM_HOUR_LABEL') }}
                  </span>
                  <select v-model="startHour" class="w-full">
                    <option
                      v-for="hour in hourOptions"
                      :key="hour"
                      :value="hour"
                    >
                      {{ hour }}
                    </option>
                  </select>
                </label>
                <label class="flex-1">
                  <span class="sr-only">
                    {{ $t('AGENT_MGMT.SCHEDULE.FROM_MINUTE_LABEL') }}
                  </span>
                  <select v-model="startMinute" class="w-full">
                    <option
                      v-for="minute in minuteOptions"
                      :key="minute"
                      :value="minute"
                    >
                      {{ minute }}
                    </option>
                  </select>
                </label>
              </div>
            </div>

            <div>
              <span class="block text-xs text-n-slate-11 mb-1">
                {{ $t('AGENT_MGMT.SCHEDULE.TO') }}
              </span>
              <div class="flex gap-2">
                <label class="flex-1">
                  <span class="sr-only">
                    {{ $t('AGENT_MGMT.SCHEDULE.TO_HOUR_LABEL') }}
                  </span>
                  <select v-model="endHour" class="w-full">
                    <option
                      v-for="hour in hourOptions"
                      :key="hour"
                      :value="hour"
                    >
                      {{ hour }}
                    </option>
                  </select>
                </label>
                <label class="flex-1">
                  <span class="sr-only">
                    {{ $t('AGENT_MGMT.SCHEDULE.TO_MINUTE_LABEL') }}
                  </span>
                  <select v-model="endMinute" class="w-full">
                    <option
                      v-for="minute in minuteOptions"
                      :key="minute"
                      :value="minute"
                    >
                      {{ minute }}
                    </option>
                  </select>
                </label>
              </div>
            </div>
          </div>

          <div
            v-if="selectedDays.length"
            class="flex flex-col gap-1 text-xs text-n-slate-11"
          >
            <span class="flex items-center gap-1.5">
              <span class="i-lucide-calendar size-3.5" />
              {{ previewDaysText }}
            </span>
            <span class="flex items-center gap-1.5">
              <span class="i-lucide-clock size-3.5" />
              {{
                $t('AGENT_MGMT.SCHEDULE.TIME_RANGE', {
                  from: startTime,
                  to: endTime,
                })
              }}
            </span>
          </div>

          <p v-if="addEntryError" class="text-sm text-n-ruby-11">
            {{ errorMessage(addEntryError) }}
          </p>

          <Button
            type="button"
            :label="$t('AGENT_MGMT.SCHEDULE.ADD_SCHEDULE')"
            @click="addSchedule"
          />

          <p class="text-xs text-n-slate-11">
            {{ $t('AGENT_MGMT.SCHEDULE.ENTRY_HELP') }}
          </p>
        </div>

        <div class="space-y-2">
          <h3 class="text-sm font-medium text-n-slate-12">
            {{ $t('AGENT_MGMT.SCHEDULE.CURRENT_SCHEDULE_TITLE') }}
          </h3>

          <p v-if="!scheduleGroups.length" class="text-sm text-n-slate-11">
            {{ $t('AGENT_MGMT.SCHEDULE.NO_ENTRIES') }}
          </p>

          <div
            v-for="group in scheduleGroups"
            :key="`${group.startTime}-${group.endTime}-${group.days.join(',')}`"
            class="flex items-center justify-between gap-3 rounded-lg border border-n-weak px-3 py-2"
          >
            <div class="flex flex-wrap items-center gap-1.5 min-w-0">
              <span
                v-for="day in orderDays(group.days)"
                :key="day"
                class="px-2 py-0.5 rounded-full text-xs font-medium bg-n-slate-3 text-n-slate-12"
              >
                {{ shortDayLabel(day) }}
              </span>
              <span class="text-sm text-n-slate-11 ms-1">
                {{
                  $t('AGENT_MGMT.SCHEDULE.TIME_RANGE', {
                    from: group.startTime,
                    to: group.endTime,
                  })
                }}
              </span>
            </div>
            <Button
              type="button"
              sm
              slate
              icon="i-lucide-trash-2"
              :label="$t('AGENT_MGMT.SCHEDULE.DELETE_ENTRY')"
              @click="removeEntry(group)"
            />
          </div>
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
