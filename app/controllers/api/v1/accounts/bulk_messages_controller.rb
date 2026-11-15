class Api::V1::Accounts::BulkMessagesController < Api::V1::Accounts::BaseController
  before_action :validate_labels

  def create
    BulkMessages::SendJob.perform_later(
      account_id: Current.account.id,
      inbox_id: bulk_message_params[:inbox_id],
      sender_id: current_user.id,
      content: bulk_message_params[:content],
      content_attributes: bulk_message_params[:content_attributes]&.to_h || {},
      attachment_signed_ids: bulk_message_params[:attachments] || [],
      phone_numbers: bulk_message_params[:phone_numbers],
      labels: labels
    )

    head :accepted
  end

  private

  def bulk_message_params
    params.permit(:inbox_id, :content, :phone_numbers, content_attributes: {}, attachments: [], labels: [])
  end

  def labels
    bulk_message_params[:labels] || []
  end

  def validate_labels
    unknown_labels = labels - Current.account.labels.where(title: labels).pluck(:title)
    return if unknown_labels.empty?

    render json: { error: I18n.t('errors.bulk_messages.unknown_labels', labels: unknown_labels.join(', ')) }, status: :unprocessable_entity
  end
end
