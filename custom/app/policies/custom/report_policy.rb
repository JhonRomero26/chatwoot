# frozen_string_literal: true

module Custom::ReportPolicy
  def view?
    super || Custom::Reports::AccessControl.self_scoped?(@account_user)
  end
end
