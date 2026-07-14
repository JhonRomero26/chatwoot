<script setup>
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import { BaseTableRow, BaseTableCell } from 'dashboard/components-next/table';

const props = defineProps({
  roles: {
    type: Array,
    required: true,
  },
  memberCountByRoleId: {
    type: Object,
    default: () => ({}),
  },
  loading: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['edit', 'delete']);

const { t } = useI18n();

const permissionLabel = permission => {
  return t(`CUSTOM_ROLE.PERMISSIONS.${permission.toUpperCase()}`);
};

const isLoading = roleId => Boolean(props.loading?.[roleId]);
const memberCount = roleId => props.memberCountByRoleId?.[roleId] ?? 0;
</script>

<template>
  <BaseTableRow v-for="role in roles" :key="role.id" :item="role">
    <template #default>
      <BaseTableCell>
        <span class="text-body-main text-n-slate-12 truncate block">
          {{ role.name }}
        </span>
      </BaseTableCell>

      <BaseTableCell>
        <div class="flex flex-wrap gap-1">
          <span
            v-for="permission in role.permissions"
            :key="permission"
            class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium bg-n-slate-3 text-n-slate-11"
          >
            {{ permissionLabel(permission) }}
          </span>
          <span
            v-if="!role.permissions.length"
            class="text-body-main text-n-slate-11 italic"
          >
            {{ t('AGENT_MGMT.ROLES.PERMISSIONS.NONE') }}
          </span>
        </div>
      </BaseTableCell>

      <BaseTableCell>
        <span class="text-body-main text-n-slate-11 block">
          {{ memberCount(role.id) }}
        </span>
      </BaseTableCell>

      <BaseTableCell align="end" class="w-24">
        <div class="flex gap-3 justify-end flex-shrink-0">
          <Button
            v-tooltip.top="$t('AGENT_MGMT.ROLES.EDIT.BUTTON_TEXT')"
            icon="i-woot-edit-pen"
            slate
            sm
            @click="emit('edit', role)"
          />
          <Button
            v-tooltip.top="$t('AGENT_MGMT.ROLES.DELETE.BUTTON_TEXT')"
            icon="i-woot-bin"
            slate
            sm
            class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
            :is-loading="isLoading(role.id)"
            @click="emit('delete', role)"
          />
        </div>
      </BaseTableCell>
    </template>
  </BaseTableRow>
</template>
