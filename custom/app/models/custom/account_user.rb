# frozen_string_literal: true

module Custom::AccountUser
  def supervisor?
    self[:supervisor]
  end

  def privileged?
    administrator? || supervisor?
  end
end
