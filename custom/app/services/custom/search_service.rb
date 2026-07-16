# frozen_string_literal: true

module Custom::SearchService
  def filter_conversations
    @conversations = if Custom::VisibilityConcern.privileged?(account_user)
                        privileged_conversations_query.order('conversations.created_at DESC')
                                                       .page(params[:page])
                                                       .per(15)
                      else
                        super.merge(Conversation.visible_to_account_user(account_user))
                      end
  end

  private

  def privileged_conversations_query
    query = current_account.conversations
                           .joins('INNER JOIN contacts ON conversations.contact_id = contacts.id')
                           .where(
                             "cast(conversations.display_id as text) ILIKE :search OR contacts.name ILIKE :search OR contacts.email\n" \
                             "                             ILIKE :search OR contacts.phone_number ILIKE :search OR contacts.identifier ILIKE :search",
                             search: "%#{search_query}%"
                           )

    return query unless current_account.feature_enabled?('advanced_search')

    apply_time_filter(query, 'conversations.last_activity_at')
  end
end
