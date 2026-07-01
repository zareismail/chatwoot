class BulkMessages::SendJob < ApplicationJob
  queue_as :low

  def perform(account_id:, inbox_id:, sender_id:, content:, phone_numbers:, content_attributes: {}, attachment_signed_ids: [])
    account = Account.find(account_id)
    inbox = account.inboxes.find(inbox_id)
    sender = account.users.find_by(id: sender_id)

    numbers = split_phone_numbers(phone_numbers)
    Rails.logger.info("[BulkMessages::SendJob] account=#{account_id} inbox=#{inbox_id} numbers_parsed=#{numbers.size}")

    matched_count = 0
    numbers.each do |raw_number|
      contact = find_contact(account, raw_number)
      if contact.blank?
        Rails.logger.info("[BulkMessages::SendJob] no contact found for phone_number=#{raw_number}")
        next
      end

      matched_count += 1
      begin
        deliver(contact: contact, inbox: inbox, sender: sender, content: content,
                content_attributes: content_attributes, attachment_signed_ids: attachment_signed_ids)
        Rails.logger.info("[BulkMessages::SendJob] delivered to contact=#{contact.id} phone_number=#{raw_number}")
      rescue StandardError => e
        Rails.logger.error("[BulkMessages::SendJob] failed for contact=#{contact.id} phone_number=#{raw_number}: #{e.class}: #{e.message}")
      end
    end

    Rails.logger.info("[BulkMessages::SendJob] done account=#{account_id} inbox=#{inbox_id} matched=#{matched_count}/#{numbers.size}")
  end

  private

  def split_phone_numbers(raw_phone_numbers)
    raw_phone_numbers.to_s.split(/[,;\n]+/).map(&:strip).reject(&:blank?).uniq
  end

  # Contacts are already stored in E.164 (see app/models/contact.rb), with whichever
  # country code is correct for them. We don't ask the sender for a country code (the
  # list of numbers may span several countries), so instead of guessing one, we try
  # progressively looser matches against the numbers already on file:
  #   1. exact E.164 match, if the entered number already has a leading +
  #   2. the digits as-is with a + prepended, in case + was simply omitted
  #   3. a suffix match on the national significant number (digits with any leading
  #      trunk zero stripped), which matches regardless of which country code the
  #      contact is actually stored under
  def find_contact(account, raw_number)
    digits = raw_number.gsub(/[^\d+]/, '')
    return if digits.blank?

    return account.contacts.find_by(phone_number: digits) if digits.start_with?('+')

    contact = account.contacts.find_by(phone_number: "+#{digits}")
    return contact if contact

    national_number = digits.sub(/\A0+/, '')
    return if national_number.blank?

    account.contacts.where('phone_number LIKE ?', "%#{national_number}").first
  end

  def deliver(contact:, inbox:, sender:, content:, content_attributes:, attachment_signed_ids:)
    contact_inbox = contact.contact_inboxes.find_by(inbox_id: inbox.id) || ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
    conversation = find_or_create_conversation(contact_inbox)

    Messages::MessageBuilder.new(
      sender,
      conversation,
      ActionController::Parameters.new(
        content: content,
        content_attributes: content_attributes,
        attachments: attachment_signed_ids
      )
    ).perform
  end

  # Always reuse the contact's existing conversation on this inbox, regardless of the
  # inbox's lock_to_single_conversation setting - a bulk message must never create a
  # second conversation for a contact who already has one.
  def find_or_create_conversation(contact_inbox)
    contact_inbox.conversations.last ||
      ConversationBuilder.new(params: ActionController::Parameters.new({}), contact_inbox: contact_inbox).perform
  end
end
