# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentRole, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:account_users).dependent(:nullify) }
  end

  describe 'validations' do
    subject(:agent_role) { build(:agent_role) }

    it { is_expected.to validate_presence_of(:name) }

    it 'allows only fork-owned permissions' do
      agent_role.permissions = ['contact_manage']

      expect(agent_role).to be_invalid
      expect(agent_role.errors[:permissions]).to be_present
    end

    it 'allows an empty permission set' do
      agent_role.permissions = []

      expect(agent_role).to be_valid
    end
  end
end
