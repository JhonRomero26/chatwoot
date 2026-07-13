json.array! @agents do |account_user|
  json.id account_user.user.id
  json.name account_user.user.name
  json.availability_status account_user.availability_status
end
