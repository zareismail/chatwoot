# Updates a contact keyed on the identifier the apps already set on it — the RGHM user id —
# so a system that only knows its own user id does not have to track Chatwoot contact ids.
class Api::V1::Accounts::Contacts::IdentifiersController < Api::V1::Accounts::BaseController
  # Every number this endpoint moves is appended here, on the contact that gained it and on
  # any contact it was taken from. Nothing else records what a contact's number used to be,
  # and a number cleared from a contact would otherwise be unrecoverable.
  PHONE_HISTORY_KEY = 'phone_number_history'.freeze

  before_action :check_authorization
  before_action :fetch_contact

  def update
    ActiveRecord::Base.transaction do
      release_phone_number
      record_phone_number_change
      @contact.assign_attributes(permitted_params)
      @contact.save!
    end
  end

  private

  def check_authorization
    authorize(Contact)
  end

  def fetch_contact
    @contact = Current.account.contacts.find_by!(identifier: params[:identifier])
  end

  # A phone number belongs to one user at a time upstream, so a contact still carrying the
  # one being assigned here is out of date. Free it rather than refuse the update: a swap
  # hands two contacts each other's number, and neither could go first otherwise. A contact
  # left without a number gets it back from its next setUser, if it really is theirs.
  def release_phone_number
    phone_number = permitted_params[:phone_number]
    return if phone_number.blank?

    holders = Current.account.contacts.where(phone_number: phone_number).where.not(id: @contact.id)
    holders.find_each do |contact|
      entry = { 'from' => phone_number, 'to' => nil, 'released_to' => @contact.identifier }
      contact.update!(phone_number: nil, additional_attributes: phone_history_for(contact, entry))
    end
  end

  # Runs before the new number is assigned, so the entry can carry the one it replaces. A
  # repeated sync sends the number a contact already has, which is not a change to record.
  def record_phone_number_change
    phone_number = permitted_params[:phone_number]
    return if phone_number.blank? || phone_number == @contact.phone_number

    entry = { 'from' => @contact.phone_number, 'to' => phone_number }
    @contact.additional_attributes = phone_history_for(@contact, entry)
  end

  # Appended, never replaced: a contact whose number moves several times keeps every step.
  def phone_history_for(contact, entry)
    attributes = contact.additional_attributes || {}
    history = attributes[PHONE_HISTORY_KEY] || []

    attributes.merge(PHONE_HISTORY_KEY => history + [entry.merge('at' => Time.current.iso8601)])
  end

  def permitted_params
    params.permit(:name, :email, :phone_number)
  end
end
