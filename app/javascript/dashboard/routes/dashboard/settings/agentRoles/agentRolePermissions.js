// ponytail: keep the allowlist in sync with `AgentRole::PERMISSIONS` in
// `custom/app/models/agent_role.rb`. If you add a permission server-side,
// add it here too — the form reads from this array.
export const AGENT_ROLE_PERMISSIONS = [
  'conversation_manage',
  'conversation_unassigned_manage',
  'conversation_participating_manage',
  'contact_manage',
  'report_manage',
  'knowledge_base_manage',
];
