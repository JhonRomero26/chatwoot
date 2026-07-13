# frozen_string_literal: true

FactoryBot.define do
  factory :agent_role do
    account
    sequence(:name) { |n| "Role #{n}" }
    permissions { [] }
  end
end
