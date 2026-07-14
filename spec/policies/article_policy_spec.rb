require 'rails_helper'

RSpec.describe ArticlePolicy, type: :policy do
  subject(:article_policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:portal) { create(:portal, account: account) }
  let(:article) { create(:article, account: account, portal: portal, author: administrator) }

  let(:administrator_context) { { user: administrator, account: account, account_user: account.account_users.first } }
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.first } }

  permissions :index? do
    context 'when administrator' do
      it { expect(article_policy).to permit(administrator_context, article) }
    end

    context 'when agent' do
      it { expect(article_policy).to permit(agent_context, article) }
    end
  end

  permissions :update?, :show?, :edit?, :create?, :destroy?, :reorder? do
    context 'when administrator' do
      it { expect(article_policy).to permit(administrator_context, article) }
    end

    context 'when agent' do
      it { expect(article_policy).not_to permit(agent_context, article) }
    end
  end

  permissions :index?, :update?, :show?, :edit?, :create?, :destroy?, :reorder? do
    context 'when agent has knowledge_base_manage agent_role permission' do
      let(:kb_manager) { create(:user, account: account, role: :agent) }
      let(:kb_manager_role) { create(:agent_role, account: account, permissions: ['knowledge_base_manage']) }
      let(:kb_manager_context) { { user: kb_manager, account: account, account_user: kb_manager.account_users.find_by(account: account) } }

      before { kb_manager.account_users.find_by(account: account).update!(agent_role: kb_manager_role) }

      it { expect(article_policy).to permit(kb_manager_context, article) }
    end
  end
end
