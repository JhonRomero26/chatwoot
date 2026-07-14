import { describe, it, expect, vi, beforeEach } from 'vitest';
import { actions } from '../agentRoles';
import types from '../../mutation-types';

vi.mock('../../../api/agentRoles', () => ({
  default: {
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
  },
}));

import AgentRolesAPI from '../../../api/agentRoles';

const flushPromises = () =>
  new Promise(resolve => {
    setImmediate(resolve);
  });

describe('agentRoles store actions', () => {
  let commit;

  beforeEach(() => {
    vi.clearAllMocks();
    commit = vi.fn();
  });

  it('createAgentRole commits ADD and clears creatingItem', async () => {
    const payload = {
      name: 'Supervisor',
      permissions: ['conversation_manage'],
    };
    const responseData = { id: 1, ...payload };
    AgentRolesAPI.create.mockResolvedValue({ data: responseData });

    await actions.createAgentRole({ commit }, payload);
    await flushPromises();

    expect(AgentRolesAPI.create).toHaveBeenCalledWith(payload);
    expect(commit).toHaveBeenCalledWith(types.ADD_AGENT_ROLE, responseData);
    expect(commit).toHaveBeenCalledWith(
      types.SET_AGENT_ROLE_UI_FLAG,
      expect.objectContaining({ creatingItem: false })
    );
  });

  it('updateAgentRole commits EDIT and clears updatingItem', async () => {
    const payload = {
      id: 1,
      name: 'Senior Supervisor',
      permissions: ['report_manage'],
    };
    const responseData = { ...payload };
    AgentRolesAPI.update.mockResolvedValue({ data: responseData });

    await actions.updateAgentRole({ commit }, payload);
    await flushPromises();

    expect(AgentRolesAPI.update).toHaveBeenCalledWith(1, {
      name: 'Senior Supervisor',
      permissions: ['report_manage'],
    });
    expect(commit).toHaveBeenCalledWith(types.EDIT_AGENT_ROLE, responseData);
  });

  it('deleteAgentRole commits DELETE and clears deletingItem', async () => {
    AgentRolesAPI.delete.mockResolvedValue({});

    await actions.deleteAgentRole({ commit }, 1);
    await flushPromises();

    expect(AgentRolesAPI.delete).toHaveBeenCalledWith(1);
    expect(commit).toHaveBeenCalledWith(types.DELETE_AGENT_ROLE, 1);
  });
});
