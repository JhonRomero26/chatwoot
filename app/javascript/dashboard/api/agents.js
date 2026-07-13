/* global axios */

import ApiClient from './ApiClient';

class Agents extends ApiClient {
  constructor() {
    super('agents', { accountScoped: true });
  }

  getAvailabilitySchedule(agentId) {
    return axios.get(`${this.url}/${agentId}/availability_schedule`);
  }

  updateAvailabilitySchedule(agentId, payload) {
    return axios.put(`${this.url}/${agentId}/availability_schedule`, payload);
  }

  bulkInvite({ emails }) {
    return axios.post(`${this.url}/bulk_create`, {
      emails,
    });
  }
}

export default new Agents();
