export const AGENT_ROLE_IDS = {
  ADMINISTRATOR: 'administrator',
  AGENT: 'agent',
};

const AGENT_ROLE_PREFIX = 'agent_role:';
const CUSTOM_ROLE_PREFIX = 'custom_role:';

const agentRoleOptionId = agentRoleId => `${AGENT_ROLE_PREFIX}${agentRoleId}`;
const customRoleOptionId = customRoleId =>
  `${CUSTOM_ROLE_PREFIX}${customRoleId}`;

const hasOption = (options, optionId) =>
  options.some(option => option.id === optionId);

const translateRoleLabel = (t, roleId) => {
  if (roleId === AGENT_ROLE_IDS.ADMINISTRATOR) {
    return t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR');
  }

  return t('AGENT_MGMT.AGENT_TYPES.AGENT');
};

export const buildAgentRoles = (
  t,
  agentRoles = [],
  legacyCustomRole = null
) => {
  const options = [
    {
      id: AGENT_ROLE_IDS.ADMINISTRATOR,
      label: translateRoleLabel(t, AGENT_ROLE_IDS.ADMINISTRATOR),
    },
    ...agentRoles.map(role => ({
      id: agentRoleOptionId(role.id),
      label: role.name,
      permissions: role.permissions || [],
    })),
    {
      id: AGENT_ROLE_IDS.AGENT,
      label: translateRoleLabel(t, AGENT_ROLE_IDS.AGENT),
    },
  ];

  if (
    legacyCustomRole &&
    !hasOption(options, customRoleOptionId(legacyCustomRole.id))
  ) {
    options.splice(options.length - 1, 0, {
      id: customRoleOptionId(legacyCustomRole.id),
      label: legacyCustomRole.name,
      permissions: legacyCustomRole.permissions || [],
    });
  }

  return options;
};

export const agentRoleId = agent => {
  if (agent.custom_role_id) {
    return customRoleOptionId(agent.custom_role_id);
  }

  if (agent.role === AGENT_ROLE_IDS.ADMINISTRATOR) {
    return AGENT_ROLE_IDS.ADMINISTRATOR;
  }

  return agent.agent_role_id
    ? agentRoleOptionId(agent.agent_role_id)
    : AGENT_ROLE_IDS.AGENT;
};

export const agentRolePayload = roleId => {
  if (roleId.startsWith(AGENT_ROLE_PREFIX)) {
    return {
      role: 'agent',
      agent_role_id: Number(roleId.replace(AGENT_ROLE_PREFIX, '')),
      custom_role_id: null,
    };
  }

  if (roleId.startsWith(CUSTOM_ROLE_PREFIX)) {
    return {
      role: 'agent',
      custom_role_id: Number(roleId.replace(CUSTOM_ROLE_PREFIX, '')),
      agent_role_id: null,
    };
  }

  switch (roleId) {
    case AGENT_ROLE_IDS.ADMINISTRATOR:
      return {
        role: 'administrator',
        agent_role_id: null,
        custom_role_id: null,
      };
    default:
      return { role: 'agent', agent_role_id: null, custom_role_id: null };
  }
};

export const agentRoleLabel = (agent, t) => {
  if (agent.custom_role_id) {
    return agent.custom_role?.name || '';
  }

  if (agent.agent_role_id) {
    return agent.agent_role?.name || '';
  }

  return translateRoleLabel(t, agentRoleId(agent));
};

export const agentRolePermissions = agent => {
  if (agent.custom_role_id) {
    return agent.custom_role?.permissions || [];
  }

  if (agent.agent_role_id) {
    return agent.agent_role?.permissions || [];
  }

  return [];
};
