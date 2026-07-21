class Contacts::PushNotificationService
  pattr_initialize [:contact!, :message!]

  def perform
    return unless contact.identifier.present?
    return unless message.outgoing?
    return if contact.online_presence?

    send_push_notification
  end

  private

  def send_push_notification
    RestClient.post(
      notification_service_url,
      payload.to_json,
      { content_type: :json, accept: :json }
    )
    Rails.logger.info("Contact push notification sent for contact##{contact.id}")
  rescue *ExceptionList::REST_CLIENT_EXCEPTIONS => e
    Rails.logger.error("ContactPushNotification: HTTP error for contact##{contact.id}: #{e.message}")
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message.account).capture_exception
  end

  def notification_service_url
    ENV.fetch('CONTACT_PUSH_NOTIFICATION_URL', 'https://rghm-firebase-notifs.hossein-2006man.workers.dev/send')
  end

  def payload
    {
      user_ids: [contact.identifier],
      data: {
        android: {
          notification: {
            title: notification_title,
            channel_id: 'default',
            body: notification_body,
            image: ''
          },
          data: {
            type: 'notification',
            link: conversation_link
          }
        },
        webpush: {
          data: {
            type: 'notification',
            title: notification_title,
            body: notification_body,
            image: '',
            link: conversation_link
          },
          fcm_options: {
            link: conversation_link
          }
        }
      }
    }
  end

  def notification_title
    message.sender&.name.presence || 'New Message'
  end

  def notification_body
    message.content.presence&.truncate(150) || 'You have a new message'
  end

  def conversation_link
    website = message.inbox.channel.try(:website_url).presence
    return '' unless website

    path = ENV.fetch('CONTACT_PUSH_NOTIFICATION_DEEPLINK_PATH', '/chat')
    "#{website}#{path}"
  end
end
