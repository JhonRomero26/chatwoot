export const AGENT_ROLE_IDS = {
  ADMINISTRATOR: 'administrator',
  SUPERVISOR: 'supervisor',
  AGENT: 'agent',
};

const CUSTOM_ROLE_PREFIX = 'custom_role:';

const customRoleOptionId = customRoleId => `${CUSTOM_ROLE_PREFIX}${customRoleId}`;

const findCustomRole = (customRoles, customRoleId) =>
  customRoles.find(role => role.id === customRoleId);

export const buildAgentRoles = (t, customRoles = []) => [
  {
    id: AGENT_ROLE_IDS.ADMINISTRATOR,
    label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR'),
  },
  {
    id: AGENT_ROLE_IDS.SUPERVISOR,
    label: t('AGENT_MGMT.AGENT_TYPES.SUPERVISOR'),
  },
  {
    id: AGENT_ROLE_IDS.AGENT,
    label: t('AGENT_MGMT.AGENT_TYPES.AGENT'),
  },
  ...customRoles.map(role => ({
    id: customRoleOptionId(role.id),
    label: role.name,
    permissions: role.permissions || [],
  })),
];

export const agentRoleId = agent => {
  if (agent.custom_role_id) {
    return customRoleOptionId(agent.custom_role_id);
  }

  if (agent.role === AGENT_ROLE_IDS.ADMINISTRATOR) {
    return AGENT_ROLE_IDS.ADMINISTRATOR;
  }

  return agent.supervisor ? AGENT_ROLE_IDS.SUPERVISOR : AGENT_ROLE_IDS.AGENT;
};

export const agentRolePayload = roleId => {
  if (roleId.startsWith(CUSTOM_ROLE_PREFIX)) {
    return {
      role: 'agent',
      supervisor: false,
      custom_role_id: Number(roleId.replace(CUSTOM_ROLE_PREFIX, '')),
    };
  }

  switch (roleId) {
    case AGENT_ROLE_IDS.ADMINISTRATOR:
      return { role: 'administrator', supervisor: false, custom_role_id: null };
    case AGENT_ROLE_IDS.SUPERVISOR:
      return { role: 'agent', supervisor: true, custom_role_id: null };
    default:
      return { role: 'agent', supervisor: false, custom_role_id: null };
  }
};

export const agentRoleLabel = (agent, t, customRoles = []) => {
  if (agent.custom_role_id) {
    return findCustomRole(customRoles, agent.custom_role_id)?.name || '';
  }

  return t(`AGENT_MGMT.AGENT_TYPES.${agentRoleId(agent).toUpperCase()}`);
};

export const agentRolePermissions = (agent, customRoles = []) => {
  if (!agent.custom_role_id) {
    return [];
  }

  return findCustomRole(customRoles, agent.custom_role_id)?.permissions || [];
};
