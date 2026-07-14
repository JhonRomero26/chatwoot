# frozen_string_literal: true

# Neither Api::V1::Accounts::Conversations::AssignmentsController,
# ActionService, nor BulkActionsJob expose a `prepend_mod_with`/
# `include_mod_with` hook of their own, so the assignment self-lock overlays
# are prepended explicitly here (mirrors
# config/initializers/03_custom_reports_overlays.rb). ActionService and
# BulkActionsJob in particular need `prepend` (not `include`) since the
# methods they intercept are defined directly on the class.
#
# BulkActionsJob is the async path used by the right-click "Assign agent"
# context menu (POST /api/v1/accounts/:id/bulk_actions); without the overlay
# an agent could bypass the AssignmentsController guard by going through the
# bulk endpoint.
Rails.application.config.to_prepare do
  {
    Api::V1::Accounts::Conversations::AssignmentsController => Custom::Api::V1::Accounts::Conversations::AssignmentsController,
    ActionService => Custom::Conversations::AssignmentGuard,
    BulkActionsJob => Custom::Conversations::BulkAssignmentGuard
  }.each do |klass, overlay|
    klass.prepend(overlay) unless klass.ancestors.include?(overlay)
  end
end
