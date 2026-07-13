# frozen_string_literal: true

class CreateAgentRolesAndReplaceSupervisor < ActiveRecord::Migration[7.1]
  class MigrationAccount < ApplicationRecord
    self.table_name = 'accounts'
  end

  class MigrationAgentRole < ApplicationRecord
    self.table_name = 'agent_roles'
  end

  class MigrationAccountUser < ApplicationRecord
    self.table_name = 'account_users'
  end

  SUPERVISOR_PERMISSIONS = %w[conversation_manage report_manage].freeze

  def up
    create_table :agent_roles do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :permissions, array: true, default: [], null: false

      t.timestamps
    end

    add_index :agent_roles, [:account_id, :name], unique: true

    add_reference :account_users, :agent_role, foreign_key: { on_delete: :nullify }, index: true
    add_column :account_users, :availability_schedule_timezone, :string

    backfill_supervisors

    remove_column :account_users, :supervisor, :boolean
  end

  def down
    add_column :account_users, :supervisor, :boolean, default: false, null: false

    MigrationAccountUser.reset_column_information
    MigrationAgentRole.reset_column_information

    MigrationAccountUser.where.not(agent_role_id: nil).find_each do |account_user|
      agent_role = MigrationAgentRole.find_by(id: account_user.agent_role_id)
      next if agent_role.blank?

      next unless agent_role.name == 'Supervisor' && agent_role.permissions == SUPERVISOR_PERMISSIONS

      account_user.update_columns(supervisor: true)
    end

    remove_reference :account_users, :agent_role, foreign_key: true, index: true
    remove_column :account_users, :availability_schedule_timezone, :string
    drop_table :agent_roles
  end

  private

  def backfill_supervisors
    MigrationAccountUser.reset_column_information

    MigrationAccount.find_each do |account|
      supervisor_rows = MigrationAccountUser.where(account_id: account.id, role: 0, supervisor: true)
      next if supervisor_rows.blank?

      supervisor_role = MigrationAgentRole.create!(
        account_id: account.id,
        name: 'Supervisor',
        permissions: SUPERVISOR_PERMISSIONS
      )

      supervisor_rows.update_all(agent_role_id: supervisor_role.id)
    end
  end
end
