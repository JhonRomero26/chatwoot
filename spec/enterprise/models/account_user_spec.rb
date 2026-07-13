# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountUser, type: :model do
  describe 'associations' do
    # option and dependant nullify
    it { is_expected.to belong_to(:custom_role).optional }
  end

  describe 'permissions' do
    context 'when custom role is assigned' do
      it 'returns permissions of the custom role along with `custom_role` permission' do
        account = create(:account)
        custom_role = create(:custom_role, account: account)
        account_user = create(:account_user, account: account, custom_role: custom_role)

        expect(account_user.permissions).to eq(custom_role.permissions + ['custom_role'])
      end
    end

    context 'when custom role is not assigned' do
      it 'returns permissions of the default role' do
        account = create(:account)
        account_user = create(:account_user, account: account)

        expect(account_user.permissions).to eq([account_user.role])
      end
    end

    context 'when both a restrictive custom_role and a leftover agent_role are present' do
      it 'does not grant conversation_manage/report_manage from the agent_role' do
        account = create(:account)
        custom_role = create(:custom_role, account: account, permissions: ['contact_manage'])
        agent_role = create(:agent_role, account: account, permissions: %w[conversation_manage report_manage])
        account_user = create(:account_user, account: account, custom_role: custom_role)

        # simulate a leftover/concurrently-set agent_role_id bypassing the write-path guard
        account_user.update_column(:agent_role_id, agent_role.id) # rubocop:disable Rails/SkipsModelValidations

        expect(account_user.permissions).to eq(custom_role.permissions + ['custom_role'])
        expect(account_user.conversation_manage?).to be(false)
        expect(account_user.report_manage?).to be(false)
      end
    end
  end

  describe 'filtered unread count invalidation' do
    it 'invalidates filtered counts when the custom role assignment changes' do
      account = create(:account)
      user = create(:user)
      account_user = create(:account_user, account: account, user: user)
      custom_role = create(:custom_role, account: account)
      invalidator = instance_double(Conversations::UnreadCounts::FilteredCountInvalidator, user_visibility_changed!: true)

      allow(Conversations::UnreadCounts::FilteredCountInvalidator).to receive(:new).and_return(invalidator)
      allow(Rails.configuration.dispatcher).to receive(:dispatch)

      account_user.update!(custom_role_id: custom_role.id)

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id)
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.cache_invalidated',
        kind_of(Time),
        account: account,
        cache_keys: account.cache_keys
      )
    end
  end

  describe 'audit log' do
    context 'when account user is created' do
      it 'has associated audit log created' do
        account_user = create(:account_user)
        account_user_audit_log = Audited::Audit.where(auditable_type: 'AccountUser', action: 'create').first
        expect(account_user_audit_log).to be_present
        expect(account_user_audit_log.associated).to eq(account_user.account)
      end
    end

    context 'when account user is updated' do
      it 'has associated audit log created' do
        account_user = create(:account_user)
        account_user.update!(availability: 'offline')
        account_user_audit_log = Audited::Audit.where(auditable_type: 'AccountUser', action: 'update').first
        expect(account_user_audit_log).to be_present
        expect(account_user_audit_log.associated).to eq(account_user.account)
        expect(account_user_audit_log.audited_changes).to eq('availability' => [0, 1])
      end
    end
  end
end
