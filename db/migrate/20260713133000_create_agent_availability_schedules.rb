# frozen_string_literal: true

class CreateAgentAvailabilitySchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_availability_schedules do |t|
      t.references :account_user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :day_of_week, null: false
      t.integer :start_minutes, null: false
      t.integer :end_minutes, null: false
      t.string :timezone, null: false

      t.timestamps
    end

    add_index :agent_availability_schedules, [:account_user_id, :day_of_week],
              name: 'index_agent_availability_schedules_on_account_user_and_day'
    add_index :agent_availability_schedules, [:account_user_id, :day_of_week, :start_minutes, :end_minutes],
              unique: true, name: 'index_agent_availability_schedules_on_account_user_day_range'
  end
end
