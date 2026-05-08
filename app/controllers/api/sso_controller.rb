module Api
  class SsoController < ApplicationController
    skip_before_action :verify_authenticity_token
    protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format.json? }

    # POST /api/sso/validate_token
    def validate_token
      token = params[:token]
      provider = params[:provider] || 'entra_id'
      
      unless token
        render json: { error: 'Token is required' }, status: :bad_request
        return
      end

      begin
        # Validate JWT token from Entra ID
        decoded_token = validate_jwt_token(token, provider)
        
        if decoded_token
          # Find or create Spree user
          user = find_or_create_user(decoded_token, provider)
          
          if user
            # Generate Spree session token
            spree_token = generate_spree_token(user)
            
            render json: {
              success: true,
              user: {
                id: user.id,
                email: user.email,
                first_name: user.first_name,
                last_name: user.last_name
              },
              spree_token: spree_token,
              expires_at: 1.hour.from_now.iso8601
            }
          else
            render json: { error: 'Failed to create user' }, status: :unprocessable_entity
          end
        else
          render json: { error: 'Invalid token' }, status: :unauthorized
        end
      rescue => e
        Rails.logger.error "SSO Token Validation Error: #{e.message}"
        render json: { error: 'Token validation failed' }, status: :internal_server_error
      end
    end

    # POST /api/sso/create_user
    def create_user
      user_data = params[:user_data]
      provider = params[:provider] || 'entra_id'
      
      unless user_data
        render json: { error: 'User data is required' }, status: :bad_request
        return
      end

      begin
        user = find_or_create_user(user_data, provider)
        
        if user
          spree_token = generate_spree_token(user)
          
          render json: {
            success: true,
            user: {
              id: user.id,
              email: user.email,
              first_name: user.first_name,
              last_name: user.last_name
            },
            spree_token: spree_token,
            expires_at: 1.hour.from_now.iso8601
          }
        else
          render json: { error: 'Failed to create user' }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error "SSO User Creation Error: #{e.message}"
        render json: { error: 'User creation failed' }, status: :internal_server_error
      end
    end

    private

    def validate_jwt_token(token, provider)
      case provider
      when 'entra_id'
        validate_entra_id_token(token)
      else
        nil
      end
    end

    def validate_entra_id_token(token)
      # For now, simple token validation
      # In production, you should validate against Entra ID's public keys
      begin
        # Decode JWT without verification (for development)
        decoded = JWT.decode(token, nil, false)
        
        # Check token claims
        payload = decoded[0]
        
        # Validate required claims
        return nil unless payload['sub']
        return nil unless payload['email']
        return nil unless payload['iss']
        
        # Check if token is expired
        return nil if payload['exp'] && Time.at(payload['exp']) < Time.current
        
        # Return user data from token
        {
          sub: payload['sub'],
          email: payload['email'],
          first_name: payload['given_name'] || payload['name']&.split&.first,
          last_name: payload['family_name'] || payload['name']&.split&.last,
          name: payload['name'],
          provider: 'entra_id',
          provider_id: payload['sub']
        }
      rescue JWT::DecodeError => e
        Rails.logger.error "JWT Decode Error: #{e.message}"
        nil
      end
    end

    def find_or_create_user(user_data, provider)
      # Find existing user by provider ID
      existing_user = Spree::User.joins(:social_accounts)
                               .find_by(social_accounts: { 
                                 provider: provider, 
                                 uid: user_data[:provider_id] || user_data[:sub] 
                               })

      return existing_user if existing_user

      # Find existing user by email
      email_user = Spree::User.find_by(email: user_data[:email])
      
      if email_user
        # Link social account to existing user
        create_social_account(email_user, user_data, provider)
        return email_user
      end

      # Create new user
      user = Spree::User.new(
        email: user_data[:email],
        first_name: user_data[:first_name],
        last_name: user_data[:last_name],
        password: SecureRandom.hex(16), # Random password for SSO users
        password_confirmation: SecureRandom.hex(16)
      )

      if user.save
        create_social_account(user, user_data, provider)
        user
      else
        Rails.logger.error "User creation failed: #{user.errors.full_messages.join(', ')}"
        nil
      end
    end

    def create_social_account(user, user_data, provider)
      # Create social account record
      user.social_accounts.create!(
        provider: provider,
        uid: user_data[:provider_id] || user_data[:sub]
      )
    end

    def generate_spree_token(user)
      # Use Spree's existing token generation
      # This is a simplified version
      payload = {
        user_id: user.id,
        exp: 1.hour.from_now.to_i,
        iat: Time.current.to_i
      }
      
      JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
    end
  end
end
