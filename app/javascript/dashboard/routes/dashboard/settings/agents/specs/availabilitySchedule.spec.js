import {
  buildAvailabilityPayload,
  buildWeeklySchedule,
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
});
