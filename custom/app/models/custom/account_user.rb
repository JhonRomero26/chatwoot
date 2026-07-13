# frozen_string_literal: true

module Custom::AccountUser
  def self.prepended(base)
    base.has_many :agent_availability_schedules, dependent: :destroy
  end

  def supervisor?
    self[:supervisor]
  end

  def privileged?
    administrator? || supervisor?
  end
end
