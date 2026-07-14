# frozen_string_literal: true

module CustomOverlayBootAssertion
  module_function

  # Class names are resolved lazily inside `verify!`, strictly after the
  # eager_load guard. Referencing the real constants at module-body load time
  # would force-autoload app/models & app/controllers during initializer
  # loading, which fails in non-eager-load environments (development/test
  # before Zeitwerk's main autoloader finishes wiring the custom/ root).
  OVERLAYS = {
    'AccountUser' => 'Custom::AccountUser',
    'Conversation' => 'Custom::Conversation',
    'Conversations::PermissionFilterService' => 'Custom::Conversations::PermissionFilterService',
    'ConversationPolicy' => 'Custom::ConversationPolicy',
    'ContactPolicy' => 'Custom::ContactPolicy',
    'ArticlePolicy' => 'Custom::ArticlePolicy',
    'SearchService' => 'Custom::SearchService',
    'ActionCableListener' => 'Custom::ActionCableListener',
    'Api::V1::Accounts::AgentsController' => 'Custom::Api::V1::Accounts::AgentsController',
    'ReportPolicy' => 'Custom::ReportPolicy',
    'Api::V2::Accounts::ReportsController' => 'Custom::Api::V2::Accounts::ReportsController',
    'V2::ReportBuilder' => 'Custom::V2::ReportBuilder',
    'Reports::RawDataSource' => 'Custom::Reports::RawDataSource',
    'V2::Reports::OutgoingMessagesCountBuilder' => 'Custom::V2::Reports::OutgoingMessagesCountBuilder',
    'V2::Reports::DrilldownBuilder' => 'Custom::V2::Reports::DrilldownBuilder'
  }.freeze

  def verify!
    return unless Rails.configuration.eager_load

    missing = OVERLAYS.filter_map do |klass_name, overlay_name|
      klass = klass_name.constantize
      overlay = overlay_name.constantize
      klass_name unless klass.ancestors.include?(overlay)
    end

    return if missing.empty?

    raise "Custom overlay boot assertion failed for: #{missing.join(', ')}"
  end
end

Rails.application.config.after_initialize do
  CustomOverlayBootAssertion.verify!
end
