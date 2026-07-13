import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import AgentRolesAPI from '../../api/agentRoles';

export const state = {
  records: [],
  uiFlags: {
    fetchingList: false,
  },
};

export const getters = {
  getAgentRoles($state) {
    return $state.records;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  getAgentRoles: async ({ commit }) => {
    commit(types.default.SET_AGENT_ROLE_UI_FLAG, { fetchingList: true });
    try {
      const response = await AgentRolesAPI.get();
      commit(types.default.SET_AGENT_ROLES, response.data);
      commit(types.default.SET_AGENT_ROLE_UI_FLAG, { fetchingList: false });
      return response.data;
    } catch (error) {
      commit(types.default.SET_AGENT_ROLE_UI_FLAG, { fetchingList: false });
      return throwErrorMessage(error);
    }
  },
};

export const mutations = {
  [types.default.SET_AGENT_ROLE_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.default.SET_AGENT_ROLES]: MutationHelpers.set,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
