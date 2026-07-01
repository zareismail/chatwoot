class Api::V1::Accounts::BulkMessagesController < Api::V1::Accounts::BaseController
  def create
    BulkMessages::SendJob.perform_later(
      account_id: Current.account.id,
      inbox_id: bulk_message_params[:inbox_id],
      sender_id: current_user.id,
      content: bulk_message_params[:content],
      content_attributes: bulk_message_params[:content_attributes]&.to_h || {},
      attachment_signed_ids: bulk_message_params[:attachments] || [],
      phone_numbers: bulk_message_params[:phone_numbers]
    )

    head :accepted
  end

  private

  def bulk_message_params
    params.permit(:inbox_id, :content, :phone_numbers, content_attributes: {}, attachments: [])
  end
end
