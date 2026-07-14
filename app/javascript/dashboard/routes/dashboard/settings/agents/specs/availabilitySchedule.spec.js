import {
  buildAvailabilityPayload,
  buildWeeklySchedule,
  groupScheduleByRange,
  validateDayRanges,
} from '../availabilitySchedule';

describe('availabilitySchedule helpers', () => {
  it('builds a full seven-day schedule from the API payload', () => {
    const weeklySchedule = buildWeeklySchedule([
      {
        day_of_week: 1,
        ranges: [{ start_minutes: 540, end_minutes: 720 }],
      },
    ]);

    expect(weeklySchedule).toHaveLength(7);
    expect(weeklySchedule[1].ranges).toEqual([
      { startTime: '09:00', endTime: '12:00' },
    ]);
    expect(weeklySchedule[2].ranges).toEqual([]);
  });

  it('rejects overlapping ranges on the same day', () => {
    expect(
      validateDayRanges([
        { startTime: '09:00', endTime: '12:00' },
        { startTime: '11:30', endTime: '13:00' },
      ])
    ).toBe('OVERLAP');
  });

  it('serializes the editor state back to the API payload', () => {
    expect(
      buildAvailabilityPayload({
        timezone: 'UTC',
        weeklySchedule: [
          { dayOfWeek: 1, ranges: [{ startTime: '09:00', endTime: '12:00' }] },
        ],
      })
    ).toEqual({
      timezone: 'UTC',
      weekly_schedule: [
        {
          day_of_week: 1,
          ranges: [{ start_minutes: 540, end_minutes: 720 }],
        },
      ],
    });
  });

  describe('groupScheduleByRange', () => {
    it('groups days that share an identical time range into one entry', () => {
      const weeklySchedule = buildWeeklySchedule();
      weeklySchedule[1].ranges.push({ startTime: '09:00', endTime: '17:00' });
      weeklySchedule[2].ranges.push({ startTime: '09:00', endTime: '17:00' });
      weeklySchedule[3].ranges.push({ startTime: '13:00', endTime: '15:00' });

      expect(groupScheduleByRange(weeklySchedule)).toEqual([
        { startTime: '09:00', endTime: '17:00', days: [1, 2] },
        { startTime: '13:00', endTime: '15:00', days: [3] },
      ]);
    });

    it('returns an empty list when nothing is scheduled', () => {
      expect(groupScheduleByRange(buildWeeklySchedule())).toEqual([]);
    });

    it('sorts groups by start time', () => {
      const weeklySchedule = buildWeeklySchedule();
      weeklySchedule[1].ranges.push({ startTime: '13:00', endTime: '15:00' });
      weeklySchedule[2].ranges.push({ startTime: '09:00', endTime: '11:00' });

      expect(
        groupScheduleByRange(weeklySchedule).map(g => g.startTime)
      ).toEqual(['09:00', '13:00']);
    });
  });
});

describe('multi-day entry workflow (adding, overlap rejection, removal)', () => {
  it('adds one range to every selected day, rejects an overlapping addition, and removes an entry from every affected day', () => {
    const weeklySchedule = buildWeeklySchedule();
    const selectedDays = [1, 2];
    const newRange = { startTime: '09:00', endTime: '12:00' };

    // Simulates the component's addSchedule(): validate per day, then apply.
    const blockingError = selectedDays
      .map(day => validateDayRanges([...weeklySchedule[day].ranges, newRange]))
      .find(Boolean);
    expect(blockingError).toBeFalsy();

    selectedDays.forEach(day => {
      weeklySchedule[day].ranges.push({ ...newRange });
    });

    expect(groupScheduleByRange(weeklySchedule)).toEqual([
      { startTime: '09:00', endTime: '12:00', days: [1, 2] },
    ]);

    // Overlapping addition on one of the same days is rejected.
    const overlapping = { startTime: '11:00', endTime: '13:00' };
    const overlapError = [1, 3]
      .map(day =>
        validateDayRanges([...weeklySchedule[day].ranges, overlapping])
      )
      .find(Boolean);
    expect(overlapError).toBe('OVERLAP');

    // Removing the entry clears the range from every affected day.
    const [group] = groupScheduleByRange(weeklySchedule);
    group.days.forEach(day => {
      const ranges = weeklySchedule[day].ranges;
      const index = ranges.findIndex(
        range =>
          range.startTime === group.startTime && range.endTime === group.endTime
      );
      ranges.splice(index, 1);
    });

    expect(groupScheduleByRange(weeklySchedule)).toEqual([]);
  });
});
