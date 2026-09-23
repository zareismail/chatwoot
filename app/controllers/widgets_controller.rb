# TODO : Delete this and associated spec once 'api/widget/config' end point is merged
class WidgetsController < ActionController::Base
  include WidgetHelper

  before_action :set_global_config
  before_action :set_web_widget
  before_action :ensure_account_is_active
  before_action :ensure_location_is_supported
  before_action :set_token
  before_action :set_contact
  before_action :build_contact
  after_action :allow_iframe_requests

  private

  def set_global_config
    @global_config = GlobalConfig.get(
      'LOGO_THUMBNAIL',
      'BRAND_NAME',
      'WIDGET_BRAND_URL',
      'DIRECT_UPLOADS_ENABLED',
      'MAXIMUM_FILE_UPLOAD_SIZE',
      'INSTALLATION_NAME'
    )
  end

  def set_web_widget
    @web_widget = ::Channel::WebWidget.find_by!(website_token: permitted_params[:website_token])
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error('web widget does not exist')
    render json: { error: 'web widget does not exist' }, status: :not_found
  end

  def set_token
    @token = permitted_params[:cw_conversation]
    @auth_token_params = if @token.present?
                           ::Widget::TokenService.new(token: @token).decode_token
                         else
                           {}
                         end
  end

  def set_contact
    source_id = @auth_token_params[:source_id]
    @contact_inbox = ::ContactInbox.find_by(inbox_id: @web_widget.inbox.id, source_id: source_id) if source_id.present?
    @contact = @contact_inbox&.contact

    # An expired or unknown token resolves to nothing. Handing it back to the widget
    # would only make every request it signs return a 404, so drop it and let whoever
    # comes next mint a session that works.
    @token = nil if @contact_inbox.nil?
  end

  def build_contact
    return if @contact.present?

    # An inbox that mandates HMAC cannot hold an unidentified contact, so there is nothing
    # to create until `setUser` says who the visitor is — creating one here only leaves a
    # nameless contact behind for every session that starts without a usable cookie. An
    # inbox that does not mandate it still serves anonymous visitors, who need a contact
    # up front because nothing else will ever give them one.
    return if @web_widget.hmac_mandatory?

    @contact_inbox, @token = build_contact_inbox_with_token(@web_widget, additional_attributes)
    @contact = @contact_inbox.contact
  end

  def ensure_account_is_active
    render json: { error: 'Account is suspended' }, status: :unauthorized unless @web_widget.inbox.account.active?
  end

  def ensure_location_is_supported; end

  def additional_attributes
    if @web_widget.inbox.account.feature_enabled?('ip_lookup')
      { created_at_ip: request.remote_ip }
    else
      {}
    end
  end

  def permitted_params
    params.permit(:website_token, :cw_conversation)
  end

  def allow_iframe_requests
    if @web_widget.allowed_domains.blank? || embedded_from_non_web_origin?
      response.headers.delete('X-Frame-Options')
    else
      domains = @web_widget.allowed_domains.split(',').map(&:strip).join(' ')
      response.headers['Content-Security-Policy'] = "frame-ancestors #{domains}"
    end
  end

  # Mobile WebViews (iOS/Android) load content from file:// or null origins,
  # which cannot match any domain in frame-ancestors. When the per-inbox flag
  # is enabled, skip frame-ancestors for these requests.
  def embedded_from_non_web_origin?
    return false unless @web_widget.allow_mobile_webview?

    origin = request.headers['Origin']
    origin.blank? || origin == 'null' || origin&.start_with?('file://')
  end
end

WidgetsController.prepend_mod_with('WidgetsController')
