<script setup>
import { ref, onMounted, computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  mode: {
    type: String,
    default: 'add',
    validator: value => ['add', 'edit'].includes(value),
  },
  selectedRole: {
    type: Object,
    default: () => ({}),
  },
  availablePermissions: {
    type: Array,
    required: true,
  },
});

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const name = ref('');
const selectedPermissions = ref([]);
const nameInput = ref(null);

const form = ref({ showLoading: false });

const rules = computed(() => ({
  name: { required, minLength: minLength(2) },
}));

const v$ = useVuelidate(rules, { name });

const resetForm = () => {
  name.value = '';
  selectedPermissions.value = [];
  v$.value.$reset();
};

const populateEditForm = () => {
  name.value = props.selectedRole.name || '';
  selectedPermissions.value = props.selectedRole.permissions || [];
};

onMounted(() => {
  if (props.mode === 'edit') {
    populateEditForm();
  }
  nameInput.value?.focus();
});

const isSubmitDisabled = computed(
  () => v$.value.$invalid || form.value.showLoading
);

const translationKey = base =>
  props.mode === 'edit'
    ? `AGENT_MGMT.ROLES.EDIT.${base}`
    : `AGENT_MGMT.ROLES.ADD.${base}`;

const modalTitle = computed(() => t(translationKey('TITLE')));
const modalDescription = computed(() => t(translationKey('DESC')));
const submitButtonText = computed(() => t(translationKey('SUBMIT')));

const togglePermission = permission => {
  if (selectedPermissions.value.includes(permission)) {
    selectedPermissions.value = selectedPermissions.value.filter(
      p => p !== permission
    );
  } else {
    selectedPermissions.value = [...selectedPermissions.value, permission];
  }
};

const submit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  form.value.showLoading = true;
  const payload = {
    name: name.value,
    permissions: selectedPermissions.value,
  };

  try {
    if (props.mode === 'edit') {
      await store.dispatch('agentRoles/updateAgentRole', {
        id: props.selectedRole.id,
        ...payload,
      });
      useAlert(t('AGENT_MGMT.ROLES.EDIT.API.SUCCESS_MESSAGE'));
    } else {
      await store.dispatch('agentRoles/createAgentRole', payload);
      useAlert(t('AGENT_MGMT.ROLES.ADD.API.SUCCESS_MESSAGE'));
    }

    resetForm();
    emit('close');
  } catch (error) {
    const errorMessage =
      error?.message || t('AGENT_MGMT.ROLES.FORM.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    form.value.showLoading = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="modalTitle"
      :header-content="modalDescription"
    />
    <form class="flex flex-col w-full" @submit.prevent="submit">
      <div class="w-full">
        <label :class="{ error: v$.name.$error }">
          {{ $t('AGENT_MGMT.ROLES.FORM.NAME.LABEL') }}
          <input
            ref="nameInput"
            v-model.trim="name"
            type="text"
            :placeholder="$t('AGENT_MGMT.ROLES.FORM.NAME.PLACEHOLDER')"
            @blur="v$.name.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label>
          {{ $t('AGENT_MGMT.ROLES.FORM.PERMISSIONS.LABEL') }}
        </label>
        <div class="flex flex-col gap-2.5 mb-4 mt-2">
          <div
            v-for="permission in availablePermissions"
            :key="permission"
            class="flex flex-col"
          >
            <div class="flex items-center">
              <input
                :id="`role-permission-${permission}`"
                :checked="selectedPermissions.includes(permission)"
                type="checkbox"
                :value="permission"
                name="permissions"
                class="ltr:mr-2 rtl:ml-2"
                @change="togglePermission(permission)"
              />
              <label
                :for="`role-permission-${permission}`"
                class="text-sm font-normal"
              >
                {{ $t(`CUSTOM_ROLE.PERMISSIONS.${permission.toUpperCase()}`) }}
              </label>
            </div>
            <p class="text-xs text-n-slate-11 ltr:ml-6 rtl:mr-6 mt-0.5">
              {{
                $t(
                  `AGENT_MGMT.ROLES.PERMISSIONS.${permission.toUpperCase()}_DESC`
                )
              }}
            </p>
          </div>
        </div>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <Button
          faded
          slate
          type="reset"
          :label="$t('AGENT_MGMT.ROLES.FORM.CANCEL_BUTTON_TEXT')"
          @click.prevent="emit('close')"
        />
        <Button
          type="submit"
          :label="submitButtonText"
          :disabled="isSubmitDisabled"
          :is-loading="form.showLoading"
        />
      </div>
    </form>
  </div>
</template>
