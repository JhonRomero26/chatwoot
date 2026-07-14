# frozen_string_literal: true

module CustomExceptions::Conversation
  class AssignmentLocked < CustomExceptions::Base
    def message
      I18n.t('errors.conversations.assignment_locked')
    end

    def to_hash
      { error: message, error_code: 'ASSIGNMENT_LOCKED' }
    end

    def http_status
      403
    end
  end
end
