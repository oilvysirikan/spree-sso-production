class Api::LineAuthController < ApplicationController
  include LineLoginGate
  skip_before_action :verify_authenticity_token

  # POST /api/line/callback
  # Verifies LINE OIDC ID token, creates/finds user, sets signed session
  def callback
    profile = verify_line_id_token(params[:id_token])
    return render json: { error: 'invalid_token' }, status: :unauthorized unless profile

    user = find_or_create_user(profile)
    return render json: { error: 'user_error' }, status: :unprocessable_entity unless user

    link_social_account(user, profile)

    session[:line_user_id] = profile[:sub]
    render json: { ok: true }
  end

  # POST /api/line/logout
  def logout
    session.delete(:line_user_id)
    render json: { ok: true }
  end

  private

  def verify_line_id_token(id_token)
    return nil if id_token.blank?

    response = HTTParty.post(
      'https://api.line.me/oauth2/v2.1/verify',
      body: { id_token: id_token, client_id: ENV['LINE_CHANNEL_ID'] },
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
      timeout: 10
    )
    return nil unless response.success?

    payload = response.parsed_response
    return nil if payload['sub'].blank?

    {
      sub:        payload['sub'],
      email:      payload['email'],
      name:       payload['name'],
      picture:    payload['picture'],
      first_name: payload['name']&.split&.first,
      last_name:  payload['name']&.split&.last(2)&.join(' ')
    }
  rescue StandardError => e
    Rails.logger.error("[LineAuth] Token verification failed: #{e.message}")
    nil
  end

  def find_or_create_user(profile)
    existing = SocialAccount.find_by(provider: 'line', uid: profile[:sub])
    return existing.spree_customer if existing

    return nil if profile[:email].blank?

    user = Spree.user_class.find_by(email: profile[:email])
    user ||= Spree.user_class.create!(
      email:      profile[:email],
      first_name: profile[:first_name],
      last_name:  profile[:last_name],
      password:   SecureRandom.hex(24)
    )
    user
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[LineAuth] User creation failed: #{e.message}")
    nil
  end

  def link_social_account(user, profile)
    SocialAccount.find_or_create_by(provider: 'line', uid: profile[:sub]) do |sa|
      sa.spree_customer = user
    end.tap do |sa|
      sa.update!(
        profile_data: { name: profile[:name], picture: profile[:picture] }
      )
    end
  end
end
