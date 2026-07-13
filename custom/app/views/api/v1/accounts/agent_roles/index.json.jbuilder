json.array! @agent_roles do |agent_role|
  json.partial! 'api/v1/models/agent_role', formats: [:json], agent_role: agent_role
end
