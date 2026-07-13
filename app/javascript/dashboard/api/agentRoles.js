import ApiClient from './ApiClient';

class AgentRoles extends ApiClient {
  constructor() {
    super('agent_roles', { accountScoped: true });
  }
}

export default new AgentRoles();
