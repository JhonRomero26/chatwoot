module Enterprise::ReportPolicy
  def view?
    @account_user.report_manage? || super
  end
end
