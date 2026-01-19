class CustomSsoController < ApplicationController

  def login
    # 1. Get parameters
    signature = params[:signature]
    token = params[:token]

    if signature.blank? || token.blank?
      render plain: "Missing parameters", status: :bad_request
      return
    end

    begin
      # 2. Decode and parse token
      # Base64.decode64 handles standard Base64. 
      # If URL-safe base64 is sent, might need strict_decode64 or urlsafe_decode64 depending on sender.
      # The provided Next.js code uses standard base64 (Buffer.toString('base64')), so decode64 is fine.
      decoded_payload = Base64.decode64(token)
      payload = JSON.parse(decoded_payload)
      email = payload['email']
      timestamp = payload['timestamp']
    rescue JSON::ParserError, TypeError, ArgumentError
      render plain: "Invalid token format", status: :bad_request
      return
    end

    # 3. Security Checks
    # A. Check for expiration (Link valid for 1 minute only)
    # Use Time.current which is timezone aware in Rails, though to_i makes it absolute.
    if Time.now.to_i - timestamp.to_i > 3600
      render plain: "Link expired", status: :unauthorized
      return
    end

    # B. Verify Signature (HMAC-SHA256)
    secret = ENV.fetch('SSO_SECRET_KEY')
    data = "#{email}#{timestamp}"
    expected_signature = OpenSSL::HMAC.hexdigest('SHA256', secret, data)

    # Use secure_compare to prevent timing attacks
    unless Rack::Utils.secure_compare(signature, expected_signature)
      render plain: "Invalid signature", status: :forbidden
      return
    end

    # 4. Log the user in
    user = User.find_by(email: email)
    
    if user
      Rails.logger.info "CustomSso: User found: #{user.email} (ID: #{user.id})"
      
      # 1. Create a token for DeviseTokenAuth (API/Client usage)
      token = user.create_token
      user.save!
      
      # 2. Sign in for standard Devise (Standard Browser Session) - Optional but good for redundancy
      request.env["devise.mapping"] = Devise.mappings[:user]
      sign_in(:user, user, store: true)

      # 3. Construct Auth Headers
      auth_headers = user.build_auth_headers(token['token'], token['client'])
      
      # 4. Set the cookie that Chatwoot frontend expects
      # The frontend parses this cookie to get the headers for API calls
      cookies['cw_d_session_info'] = {
        value: auth_headers.to_json,
        expires: 2.months.from_now,
        httponly: false, # Must be readable by JS
        secure: Rails.env.production?
      }
      
      Rails.logger.info "CustomSso: Set cw_d_session_info cookie."
      Rails.logger.info "CustomSso: Session ID: #{session.id.inspect}"
      Rails.logger.info "CustomSso: Current User: #{current_user&.email}"

      Rails.logger.info "CustomSso: params[:redirect_url]: #{params[:redirect_url]}"
      # Redirect
      account_id = user.accounts.first&.id
      valid_redirect_url = params[:redirect_url] if params[:redirect_url]&.start_with?('/') && !params[:redirect_url]&.start_with?('//')
      redirect_path = valid_redirect_url || (account_id ? "/app/accounts/#{account_id}/dashboard" : "/app/dashboard")
      
      Rails.logger.info "CustomSso: Redirecting to #{redirect_path}"
      redirect_to redirect_path
    else
      Rails.logger.error "CustomSso: User not found for email: #{email}"
      render plain: "User not found. Please provision account first.", status: :not_found
    end
  end
end
