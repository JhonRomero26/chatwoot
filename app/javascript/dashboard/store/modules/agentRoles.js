import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import AgentRolesAPI from '../../api/agentRoles';

export const state = {
  records: [],
  uiFlags: {
    fetchingList: false,
    creatingItem: false,
    updatingItem: false,
    deletingItem: false,
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

  createAgentRole: async ({ commit }, payload) => {
    commit(types.default.SET_AGENT_ROLE_UI_FLAG, { creatingItem: true });
    try {
      const response = await AgentRolesAPI.create(payload);
      commit(types.default.ADD_AGENT_ROLE, response.data);
      commit(types.default.SET_AGENT_ROLE_UI_FLAG, { creatingItem: false });
      return response.data;
    } catch (error) {
      commit(types.default.SET_AGENT_ROLE_UI_FLAG, { creatingItem: false });
      return throwErrorMessage(error);
    }
  },

  updateAgentRole: async ({ commit }, { id, ...payload }) => {
    commit(types.default.SET_AGENT_ROLE_UI_FLAG, { updatingItem: true });
    try {
      const response = await AgentRolesAPI.update(id, payload);
      commit(types.default.EDIT_AGENT_ROLE, response.data);
      commit(types.default.SET_AGENT_ROLE_UI_FLAG, { updatingItem: false });
      return response.data;
    } catch (error) {
      commit(types.default.SET_AGENT_ROLE_UI_FLAG, { updatingItem: false });
      return throwErrorMessage(error);
    }
  },

  deleteAgentRole: async ({ commit }, id) => {
    commit(types.default.SET_AGENT_ROLE_UI_FLAG, { deletingItem: true });
    try {
      await AgentRolesAPI.delete(id);
      commit(types.default.DELETE_AGENT_ROLE, id);
      commit(types.default.SET_AGENT_ROLE_UI_FLAG, { deletingItem: false });
      return id;
    } catch (error) {
      commit(types.default.SET_AGENT_ROLE_UI_FLAG, { deletingItem: false });
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
  [types.default.ADD_AGENT_ROLE]: MutationHelpers.create,
  [types.default.EDIT_AGENT_ROLE]: MutationHelpers.update,
  [types.default.DELETE_AGENT_ROLE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
