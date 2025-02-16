require 'rails_helper'

describe ::Conversations::FilterService do
  subject(:filter_service) { described_class }

  let!(:account) { create(:account) }
  let!(:user_1) { create(:user, account: account) }
  let!(:user_2) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }

  before do
    create(:inbox_member, user: user_1, inbox: inbox)
    create(:inbox_member, user: user_2, inbox: inbox)
    create(:conversation, account: account, inbox: inbox, assignee: user_1)
    create(:conversation, account: account, inbox: inbox, assignee: user_1,
                          status: 'pending', additional_attributes: { 'browser_language': 'en' })
    create(:conversation, account: account, inbox: inbox, assignee: user_1,
                          status: 'pending', additional_attributes: { 'browser_language': 'en' })
    create(:conversation, account: account, inbox: inbox, assignee: user_2)
    # unassigned conversation
    create(:conversation, account: account, inbox: inbox)
    Current.account = account
  end

  describe '#perform' do
    context 'with query present' do
      let!(:params) { { payload: [], page: 1 } }
      let(:payload) do
        [
          {
            attribute_key: 'browser_language',
            filter_operator: 'equal_to',
            values: ['en'],
            query_operator: 'AND'
          }.with_indifferent_access,
          {
            attribute_key: 'status',
            filter_operator: 'equal_to',
            values: %w[open pending],
            query_operator: nil
          }.with_indifferent_access
        ]
      end

      it 'filter conversations by custom_attributes and status' do
        params[:payload] = payload
        result = filter_service.new(params, user_1).perform
        conversations = Conversation.where("additional_attributes ->> 'browser_language' IN (?) AND status IN (?)", ['en'], [1, 2])
        expect(result.length).to be conversations.count
      end

      it 'filter conversations by tags' do
        Conversation.last.update_labels('support')
        params[:payload] = [
          {
            attribute_key: 'assignee_id',
            filter_operator: 'equal_to',
            values: [
              user_1.id,
              user_2.id
            ],
            query_operator: 'AND'
          }.with_indifferent_access,
          {
            attribute_key: 'labels',
            filter_operator: 'equal_to',
            values: [1],
            query_operator: nil
          }.with_indifferent_access
        ]
        result = filter_service.new(params, user_1).perform
        expect(result.length).to be 2
      end
    end
  end
end
