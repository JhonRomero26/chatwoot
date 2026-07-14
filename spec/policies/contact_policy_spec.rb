# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactPolicy, type: :policy do
  subject(:contact_policy) { described_class }

  let(:account) { create(:account) }

  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:contact) { create(:contact) }

  let(:administrator_context) { { user: administrator, account: account, account_user: account.account_users.first } }
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.first } }

  permissions :index?, :show?, :update? do
    context 'when administrator' do
      it { expect(contact_policy).to permit(administrator_context, contact) }
    end

    context 'when agent' do
      it { expect(contact_policy).to permit(agent_context, contact) }
    end
  end

  permissions :create? do
    context 'when administrator' do
      it { expect(contact_policy).to permit(administrator_context, contact) }
    end

    context 'when agent' do
      it { expect(contact_policy).to permit(agent_context, contact) }
    end
  end

  permissions :export?, :import? do
    context 'when agent has no contact_manage permission' do
      it { expect(contact_policy).not_to permit(agent_context, contact) }
    end

    context 'when agent has contact_manage agent_role permission' do
      let(:contact_manager) { create(:user, account: account, role: :agent) }
      let(:contact_manager_role) { create(:agent_role, account: account, permissions: ['contact_manage']) }
      let(:contact_manager_context) do
        { user: contact_manager, account: account, account_user: contact_manager.account_users.find_by(account: account) }
      end

      before { contact_manager.account_users.find_by(account: account).update!(agent_role: contact_manager_role) }

      it { expect(contact_policy).to permit(contact_manager_context, contact) }
    end
  end

  permissions :destroy? do
    context 'when administrator' do
      it { expect(contact_policy).to permit(administrator_context, contact) }
    end

    context 'when agent has contact_manage agent_role permission' do
      let(:contact_manager) { create(:user, account: account, role: :agent) }
      let(:contact_manager_role) { create(:agent_role, account: account, permissions: ['contact_manage']) }
      let(:contact_manager_context) do
        { user: contact_manager, account: account, account_user: contact_manager.account_users.find_by(account: account) }
      end

      before { contact_manager.account_users.find_by(account: account).update!(agent_role: contact_manager_role) }

      it 'stays admin-only even with contact_manage' do
        expect(contact_policy).not_to permit(contact_manager_context, contact)
      end
    end
  end
end
