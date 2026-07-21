class Contacts::ContactPushNotificationJob < ApplicationJob
  queue_as :default

  def perform(contact_id, message_id)
    contact = Contact.find_by(id: contact_id)
    message = Message.find_by(id: message_id)
    return if contact.blank? || message.blank?

    Contacts::PushNotificationService.new(contact: contact, message: message).perform
  end
end
