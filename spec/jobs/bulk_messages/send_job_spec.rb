
require 'rails_helper'

RSpec.describe BulkMessages::SendJob do
  subject(:perform_job) do
    described_class.perform_now(
      account_id: account.id,
      inbox_id: inbox.id,
      sender_id: sender.id,
      content: 'Hello from the team!',
      phone_numbers: phone_numbers
    )
  end

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:sender) { create(:user, account: account, role: :agent) }

  context 'when the inbox does not have lock_to_single_conversation enabled' do
    let(:contact) { create(:contact, account: account, phone_number: '+15557778888') }
    let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
    let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, status: 'open') }
    let(:phone_numbers) { contact.phone_number }

    before { inbox.update!(lock_to_single_conversation: false) }

    it 'still reuses the existing conversation instead of creating a second one' do
      expect { perform_job }.not_to change(Conversation, :count)
      expect(contact.reload.conversations.count).to eq(1)
      expect(conversation.reload.messages.last.content).to eq('Hello from the team!')
    end
  end

  context 'when a contact has an existing open conversation' do
    let(:contact) { create(:contact, account: account, phone_number: '+15551112222') }
    let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
    let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, status: 'open') }
    let(:phone_numbers) { contact.phone_number }

    it 'appends the message to the existing conversation instead of creating a new one' do
      expect { perform_job }.to change { conversation.reload.messages.count }.by(1)
      expect(contact.reload.conversations.count).to eq(1)
      expect(conversation.messages.last.content).to eq('Hello from the team!')
    end
  end

  context 'when a contact has an existing resolved conversation' do
    let(:contact) { create(:contact, account: account, phone_number: '+15553334444') }
    let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
    let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, status: 'resolved') }
    let(:phone_numbers) { contact.phone_number }

    it 'reuses the resolved conversation rather than creating a duplicate' do
      expect { perform_job }.to change { conversation.reload.messages.count }.by(1)
      expect(contact.reload.conversations.count).to eq(1)
    end
  end

  context 'when a contact has no existing conversation on the inbox' do
    let(:contact) { create(:contact, account: account, phone_number: '+15555556666') }
    let(:phone_numbers) { contact.phone_number }

    it 'creates exactly one conversation and delivers the message' do
      expect { perform_job }.to change(Conversation, :count).by(1)
      expect(contact.reload.conversations.count).to eq(1)
      expect(contact.conversations.last.messages.last.content).to eq('Hello from the team!')
    end
  end

  context 'when a phone number does not match any contact' do
    let(:phone_numbers) { '+19998887777' }

    it 'skips it without raising an error' do
      expect { perform_job }.not_to change(Conversation, :count)
    end
  end

  context 'when a phone number is typed with internal spaces/dashes' do
    let(:contact) { create(:contact, account: account, phone_number: '+15551234567') }
    let(:phone_numbers) { "+1 555-123 4567" }

    it 'strips the formatting instead of splitting it into multiple numbers' do
      contact
      expect { perform_job }.to change(Conversation, :count).by(1)
      expect(contact.reload.conversations.count).to eq(1)
    end
  end

  context 'when a number is entered in local format without a country code' do
    let(:contact) { create(:contact, account: account, phone_number: '+989121234567') }
    let(:phone_numbers) { '0912 123 4567' }

    it 'matches the contact via the national significant number, regardless of country' do
      contact
      expect { perform_job }.to change(Conversation, :count).by(1)
      expect(contact.reload.conversations.count).to eq(1)
    end
  end

  context 'when a list mixes numbers from different countries, all in local format' do
    let(:contact_iran) { create(:contact, account: account, phone_number: '+989121234567') }
    let(:contact_uk) { create(:contact, account: account, phone_number: '+447911123456') }
    let(:phone_numbers) { "09121234567\n07911123456" }

    it 'matches each contact under their own stored country code without being told either one' do
      contact_iran
      contact_uk

      expect { perform_job }.to change(Conversation, :count).by(2)
      expect(contact_iran.reload.conversations.count).to eq(1)
      expect(contact_uk.reload.conversations.count).to eq(1)
    end
  end

  context 'with multiple numbers in varied formats' do
    let(:contact_one) { create(:contact, account: account, phone_number: '+15551112222') }
    let(:contact_two) { create(:contact, account: account, phone_number: '+15553334444') }
    let(:phone_numbers) { "15551112222, +15553334444\n+19998887777" }

    it 'normalizes missing + signs and delivers only to matched contacts' do
      contact_one
      contact_two

      expect { perform_job }.to change(Conversation, :count).by(2)
      expect(contact_one.reload.conversations.count).to eq(1)
      expect(contact_two.reload.conversations.count).to eq(1)
    end
  end
end
