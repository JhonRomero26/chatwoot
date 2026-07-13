json.agent_id @agent.id
json.timezone @schedule_timezone
json.weekly_schedule @weekly_schedule do |row|
  json.day_of_week row[:day_of_week]
  json.ranges row[:ranges] do |range|
    json.start_minutes range[:start_minutes]
    json.end_minutes range[:end_minutes]
  end
end
