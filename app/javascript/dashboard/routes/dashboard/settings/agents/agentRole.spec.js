import {
  buildAgentRoles,
  agentRoleId,
  agentRoleLabel,
  agentRolePayload,
} from './agentRole';

describe('agentRole', () => {
  const t = key => key;

  it('maps fork-owned roles to agent role option ids', () => {
    expect(agentRoleId({ role: 'agent', agent_role_id: 7 })).toBe(
      'agent_role:7'
    );
  });

  it('serializes the fork-owned selector to agent_role_id', () => {
    expect(agentRolePayload('agent_role:7')).toEqual({
      role: 'agent',
      custom_role_id: null,
      agent_role_id: 7,
    });
  });

  it('includes fork-owned roles in the selector options', () => {
    expect(
      buildAgentRoles(t, [{ id: 7, name: 'Queue Manager', permissions: [] }])
    ).toEqual(
      expect.arrayContaining([
        { id: 'agent_role:7', label: 'Queue Manager', permissions: [] },
      ])
    );
  });

  it('serializes a legacy custom role selection without dropping custom_role_id', () => {
    expect(agentRolePayload('custom_role:7')).toEqual({
      role: 'agent',
      custom_role_id: 7,
      agent_role_id: null,
    });
  });

  it('renders the legacy custom role label when an agent has custom_role_id', () => {
    expect(
      agentRoleLabel(
        {
          role: 'agent',
          custom_role_id: 7,
          custom_role: { name: 'Queue Manager' },
        },
        t
      )
    ).toBe('Queue Manager');
  });

  it('renders the fork-owned role label when an agent has agent_role_id', () => {
    expect(
      agentRoleLabel(
        { role: 'agent', agent_role_id: 3, agent_role: { name: 'Supervisor' } },
        t
      )
    ).toBe('Supervisor');
  });
});
