# frozen_string_literal: true

class AddSupervisorToAccountUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :account_users, :supervisor, :boolean, default: false, null: false
  end
end
