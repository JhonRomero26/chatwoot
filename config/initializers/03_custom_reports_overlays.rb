# frozen_string_literal: true

Rails.application.config.to_prepare do
  {
    Api::V2::Accounts::ReportsController => Custom::Api::V2::Accounts::ReportsController,
    V2::ReportBuilder => Custom::V2::ReportBuilder,
    Reports::RawDataSource => Custom::Reports::RawDataSource,
    V2::Reports::OutgoingMessagesCountBuilder => Custom::V2::Reports::OutgoingMessagesCountBuilder,
    V2::Reports::DrilldownBuilder => Custom::V2::Reports::DrilldownBuilder
  }.each do |klass, overlay|
    klass.prepend(overlay) unless klass.ancestors.include?(overlay)
  end
end
