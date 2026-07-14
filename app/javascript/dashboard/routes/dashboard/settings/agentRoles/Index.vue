<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { picoSearch } from '@scmmishra/pico-search';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import AgentRoleModal from './AgentRoleModal.vue';
import AgentRoleTableBody from './AgentRoleTableBody.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { BaseTable } from 'dashboard/components-next/table';
import { AGENT_ROLE_PERMISSIONS } from './agentRolePermissions';

const store = useStore();
const { t } = useI18n();

const showRoleModal = ref(false);
const roleModalMode = ref('add');
const selectedRole = ref(null);
const loading = ref({});
const showDeleteConfirmationPopup = ref(false);
const activeResponse = ref({});
const searchQuery = ref('');

const records = useMapGetter('agentRoles/getAgentRoles');
const uiFlags = useMapGetter('agentRoles/getUIFlags');
const currentUser = useMapGetter('getCurrentUser');

const isAdministrator = computed(() => {
  const accountId = store.getters.getCurrentAccountId;
  const account = (currentUser.value?.accounts || []).find(
    a => Number(a.id) === Number(accountId)
  );
  return account?.role === 'administrator';
});

const memberCountByRoleId = computed(() => {
  const counts = {};
  const agents = store.getters['agents/getAgents'] || [];
  agents.forEach(agent => {
    const id = agent.agent_role_id;
    if (id) counts[id] = (counts[id] || 0) + 1;
  });
  return counts;
});

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return records.value;
  // ponytail: flatten permissions into a string field so picoSearch can
  // text-match them. The library coerces non-string fields to "" otherwise.
  const searchable = records.value.map(role => ({
    ...role,
    permissionsText: (role.permissions || []).join(' '),
  }));
  return picoSearch(searchable, query, ['name', 'permissionsText']);
});

const deleteConfirmText = computed(
  () =>
    `${t('AGENT_MGMT.ROLES.DELETE.CONFIRM.YES')} ${activeResponse.value.name}`
);
const deleteRejectText = computed(
  () =>
    `${t('AGENT_MGMT.ROLES.DELETE.CONFIRM.NO')} ${activeResponse.value.name}`
);
const deleteMessage = computed(() => ` ${activeResponse.value.name} ? `);

const tableHeaders = computed(() => [
  t('AGENT_MGMT.ROLES.LIST.TABLE_HEADER.NAME'),
  t('AGENT_MGMT.ROLES.LIST.TABLE_HEADER.PERMISSIONS'),
  t('AGENT_MGMT.ROLES.LIST.TABLE_HEADER.MEMBERS'),
  t('AGENT_MGMT.ROLES.LIST.TABLE_HEADER.ACTIONS'),
]);

onMounted(() => {
  store.dispatch('agentRoles/getAgentRoles');
  store.dispatch('agents/get');
});

const showAlertMessage = message => {
  loading.value[activeResponse.value.id] = false;
  activeResponse.value = {};
  useAlert(message);
};

const openAddModal = () => {
  roleModalMode.value = 'add';
  selectedRole.value = null;
  showRoleModal.value = true;
};

const openEditModal = role => {
  roleModalMode.value = 'edit';
  selectedRole.value = role;
  showRoleModal.value = true;
};

const hideRoleModal = () => {
  selectedRole.value = null;
  showRoleModal.value = false;
};

const openDeletePopup = response => {
  showDeleteConfirmationPopup.value = true;
  activeResponse.value = response;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteRole = async id => {
  try {
    await store.dispatch('agentRoles/deleteAgentRole', id);
    showAlertMessage(t('AGENT_MGMT.ROLES.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('AGENT_MGMT.ROLES.DELETE.API.ERROR_MESSAGE');
    showAlertMessage(errorMessage);
  }
};

const confirmDeletion = () => {
  loading.value[activeResponse.value.id] = true;
  closeDeletePopup();
  deleteRole(activeResponse.value.id);
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetchingList"
    :loading-message="$t('AGENT_MGMT.ROLES.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('AGENT_MGMT.ROLES.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('AGENT_MGMT.ROLES.HEADER')"
        :description="$t('AGENT_MGMT.ROLES.DESCRIPTION')"
        :search-placeholder="$t('AGENT_MGMT.ROLES.SEARCH_PLACEHOLDER')"
        feature-name="agent_roles"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('AGENT_MGMT.ROLES.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template v-if="isAdministrator" #actions>
          <Button
            :label="$t('AGENT_MGMT.ROLES.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddModal"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template v-if="!isAdministrator" #preBody>
      <p
        class="flex-1 py-12 text-n-slate-11 flex items-center justify-center text-base"
      >
        {{ $t('AGENT_MGMT.ROLES.FORBIDDEN') }}
      </p>
    </template>

    <template v-else #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          searchQuery
            ? $t('AGENT_MGMT.ROLES.NO_RESULTS')
            : $t('AGENT_MGMT.ROLES.LIST.404')
        "
      >
        <template #row="{ items }">
          <AgentRoleTableBody
            :roles="items"
            :member-count-by-role-id="memberCountByRoleId"
            :loading="loading"
            :available-permissions="AGENT_ROLE_PERMISSIONS"
            @edit="openEditModal"
            @delete="openDeletePopup"
          />
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showRoleModal" :on-close="hideRoleModal">
      <AgentRoleModal
        :mode="roleModalMode"
        :selected-role="selectedRole"
        :available-permissions="AGENT_ROLE_PERMISSIONS"
        @close="hideRoleModal"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('AGENT_MGMT.ROLES.DELETE.CONFIRM.TITLE')"
      :message="$t('AGENT_MGMT.ROLES.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
    />
  </SettingsLayout>
</template>
