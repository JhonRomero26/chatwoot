# frozen_string_literal: true

module Custom::Account
  def self.prepended(base)
    base.has_many :agent_roles, dependent: :destroy_async
  end
end
