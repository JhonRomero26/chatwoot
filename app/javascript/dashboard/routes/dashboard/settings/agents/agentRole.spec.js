import {
  AGENT_ROLE_IDS,
  buildAgentRoles,
  agentRoleId,
  agentRoleLabel,
  agentRolePayload,
} from './agentRole';

describe('agentRole', () => {
  const t = key => key;

  it('maps supervisor users to the supervisor label key', () => {
    expect(agentRoleId({ role: 'agent', supervisor: true })).toBe(
      AGENT_ROLE_IDS.SUPERVISOR
    );
  });

  it('serializes the supervisor selector to agent role plus supervisor flag', () => {
    expect(agentRolePayload(AGENT_ROLE_IDS.SUPERVISOR)).toEqual({
      role: 'agent',
      supervisor: true,
      custom_role_id: null,
    });
  });

  it('includes enterprise custom roles in the selector options', () => {
    expect(buildAgentRoles(t, [{ id: 7, name: 'Queue Manager', permissions: [] }])).toEqual(
      expect.arrayContaining([{ id: 'custom_role:7', label: 'Queue Manager', permissions: [] }])
    );
  });

  it('serializes a custom role selection without dropping custom_role_id', () => {
    expect(agentRolePayload('custom_role:7')).toEqual({
      role: 'agent',
      supervisor: false,
      custom_role_id: 7,
    });
  });

  it('renders the custom role label when an agent has custom_role_id', () => {
    expect(
      agentRoleLabel(
        { role: 'agent', custom_role_id: 7 },
        t,
        [{ id: 7, name: 'Queue Manager', permissions: [] }]
      )
    ).toBe('Queue Manager');
  });
});
