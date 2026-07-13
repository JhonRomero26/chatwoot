json.agent_id @agent.id
json.weekly_schedule @schedule_rows do |row|
  json.day_of_week row.day_of_week
  json.timezone row.timezone
  json.morning_start_minutes row.morning_start_minutes
  json.morning_end_minutes row.morning_end_minutes
  json.afternoon_start_minutes row.afternoon_start_minutes
  json.afternoon_end_minutes row.afternoon_end_minutes
end
