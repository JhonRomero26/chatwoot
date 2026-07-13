# frozen_string_literal: true

module Custom::Conversation
  extend ActiveSupport::Concern

  prepended do
    scope :visible_to_account_user, lambda { |account_user|
      Custom::VisibilityConcern.visible_conversations(all, account_user)
    }
  end
end
