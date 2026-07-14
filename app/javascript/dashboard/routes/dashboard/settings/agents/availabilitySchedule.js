export const DAY_KEYS = [
  'SUNDAY',
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
];

export const minutesToTimeInput = minutes => {
  const hour = `${Math.floor(minutes / 60)}`.padStart(2, '0');
  const minute = `${minutes % 60}`.padStart(2, '0');
  return `${hour}:${minute}`;
};

export const timeInputToMinutes = value => {
  if (!value) return null;

  const [hour, minute] = value.split(':').map(Number);
  if (Number.isNaN(hour) || Number.isNaN(minute)) return null;

  return hour * 60 + minute;
};

export const buildWeeklySchedule = (weeklySchedule = []) => {
  const rowsByDay = Object.fromEntries(
    weeklySchedule.map(row => [row.day_of_week, row])
  );

  return DAY_KEYS.map((_, dayOfWeek) => ({
    dayOfWeek,
    ranges: (rowsByDay[dayOfWeek]?.ranges || []).map(range => ({
      startTime: minutesToTimeInput(range.start_minutes),
      endTime: minutesToTimeInput(range.end_minutes),
    })),
  }));
};

export const validateDayRanges = ranges => {
  const normalizedRanges = ranges.map(range => ({
    startMinutes: timeInputToMinutes(range.startTime),
    endMinutes: timeInputToMinutes(range.endTime),
  }));

  if (
    normalizedRanges.some(
      range => range.startMinutes === null || range.endMinutes === null
    )
  ) {
    return 'MISSING_TIME';
  }

  if (normalizedRanges.some(range => range.startMinutes >= range.endMinutes)) {
    return 'INVALID_ORDER';
  }

  const sortedRanges = [...normalizedRanges].sort(
    (left, right) => left.startMinutes - right.startMinutes
  );

  for (let index = 1; index < sortedRanges.length; index += 1) {
    if (sortedRanges[index].startMinutes < sortedRanges[index - 1].endMinutes) {
      return 'OVERLAP';
    }
  }

  return '';
};

// Groups the per-day ranges back into "entries" (day-set + time range) for
// display, so the UI doesn't need to track entries separately from the
// per-day weeklySchedule that's already the source of truth for validation
// and the save payload.
export const groupScheduleByRange = weeklySchedule => {
  const groups = new Map();

  weeklySchedule.forEach(day => {
    day.ranges.forEach(range => {
      const key = `${range.startTime}-${range.endTime}`;
      if (!groups.has(key)) {
        groups.set(key, {
          startTime: range.startTime,
          endTime: range.endTime,
          days: [],
        });
      }
      groups.get(key).days.push(day.dayOfWeek);
    });
  });

  return [...groups.values()].sort(
    (left, right) =>
      timeInputToMinutes(left.startTime) - timeInputToMinutes(right.startTime)
  );
};

export const buildAvailabilityPayload = ({ timezone, weeklySchedule }) => ({
  timezone,
  weekly_schedule: weeklySchedule.map(day => ({
    day_of_week: day.dayOfWeek,
    ranges: day.ranges.map(range => ({
      start_minutes: timeInputToMinutes(range.startTime),
      end_minutes: timeInputToMinutes(range.endTime),
    })),
  })),
});
