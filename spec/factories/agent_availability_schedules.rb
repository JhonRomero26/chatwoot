# frozen_string_literal: true

FactoryBot.define do
  factory :agent_availability_schedule do
    account_user
    day_of_week { 1 }
    start_minutes { 540 }
    end_minutes { 720 }
    timezone { 'UTC' }
  end
end
