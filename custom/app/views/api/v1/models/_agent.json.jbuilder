json.id resource.id
json.account_id Current.account&.id
json.availability_status resource.availability_status
json.auto_offline resource.auto_offline
json.confirmed resource.confirmed?
json.email resource.email
json.provider resource.provider
json.available_name resource.available_name
json.custom_attributes resource.custom_attributes if resource.custom_attributes.present?
json.name resource.name
json.role resource.role
json.supervisor resource.current_account_user&.supervisor? || false
json.thumbnail resource.avatar_url
json.custom_role_id resource.current_account_user&.custom_role_id if ChatwootApp.enterprise?
