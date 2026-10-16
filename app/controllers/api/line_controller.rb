module Api
  class LineController < ApplicationController
    skip_before_action :verify_authenticity_token

    # POST /api/line/webhook
    # Receives events from LINE Platform (messages, follows, postbacks)
    def webhook
      body = request.body.read
      return head :unauthorized unless valid_signature?(body)

      events = JSON.parse(body)['events'] || []
      events.each { |event| handle_line_event(event) }
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    # GET /api/line/member/:line_user_id
    # Returns member profile: orders, points, linked account
    def member
      line_user_id = params[:line_user_id]
      social = SocialAccount.find_by(provider: 'line', uid: line_user_id)
      return render json: { error: 'Member not found' }, status: :not_found unless social

      user = social.spree_user
      shopify_data = ShopifySyncService.new.sync_customer_orders(email: user.email)

      render json: {
        line_user_id: line_user_id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        points: user.public_metadata&.dig('shopify_points') || shopify_data[:points],
        total_spent_thb: shopify_data[:total_spent_thb],
        total_orders: shopify_data[:total_orders],
        recent_orders: shopify_data[:orders]&.first(5)
      }
    end

    # POST /api/line/link_shopify
    # Links a LINE user to their Shopify order history by email
    # Body: { line_user_id, email }
    def link_shopify
      line_user_id = params[:line_user_id]
      email = params[:email]

      return render json: { error: 'line_user_id and email required' }, status: :bad_request unless line_user_id && email

      user = Spree::User.find_by(email: email)
      return render json: { error: 'User not found' }, status: :not_found unless user

      social = SocialAccount.find_or_create_by!(provider: 'line', uid: line_user_id) do |sa|
        sa.spree_user = user
      end

      shopify_data = ShopifySyncService.new.sync_customer_orders(email: email)
      user.public_metadata ||= {}
      user.public_metadata['shopify_points'] = shopify_data[:points]
      user.public_metadata['shopify_total_spent'] = shopify_data[:total_spent_thb]
      user.save!

      render json: {
        success: true,
        points: shopify_data[:points],
        total_spent_thb: shopify_data[:total_spent_thb],
        total_orders: shopify_data[:total_orders]
      }
    end

    # POST /api/line/notify_back_in_stock
    # Notify subscribers when product is back in stock
    # Body: { product_name, product_url, image_url }
    def notify_back_in_stock
      subscribers = SocialAccount.where(provider: 'line').pluck(:uid)
      return render json: { notified: 0 } if subscribers.empty?

      svc = LineMessagingService.new
      subscribers.each do |line_uid|
        svc.send_back_in_stock_alert(
          line_uid,
          product_name: params[:product_name],
          product_url: params[:product_url],
          image_url: params[:image_url]
        )
      rescue StandardError => e
        Rails.logger.error "Back-in-stock notify error #{line_uid}: #{e.message}"
      end

      render json: { notified: subscribers.size }
    end

    private

    def handle_line_event(event)
      case event['type']
      when 'follow'
        handle_follow(event)
      when 'message'
        handle_message(event)
      when 'postback'
        handle_postback(event)
      end
    end

    def handle_follow(event)
      line_user_id = event.dig('source', 'userId')
      Rails.logger.info "New LINE follower: #{line_user_id}"
      # Send welcome message
      LineMessagingService.new.send_text(
        line_user_id,
        "ยินดีต้อนรับ! 🎉\nเชื่อมต่อบัญชีของคุณเพื่อดูคะแนนสะสมและประวัติการสั่งซื้อ"
      )
    end

    def handle_message(event)
      line_user_id = event.dig('source', 'userId')
      text = event.dig('message', 'text')&.strip&.downcase
      return unless text

      case text
      when 'คะแนน', 'points', 'แต้ม'
        send_points_info(line_user_id)
      when 'ออเดอร์', 'order', 'คำสั่งซื้อ'
        send_order_history(line_user_id)
      end
    end

    def handle_postback(event)
      line_user_id = event.dig('source', 'userId')
      data = event.dig('postback', 'data')
      Rails.logger.info "LINE postback from #{line_user_id}: #{data}"
    end

    def send_points_info(line_user_id)
      social = SocialAccount.find_by(provider: 'line', uid: line_user_id)
      unless social
        LineMessagingService.new.send_text(line_user_id, "กรุณาเชื่อมต่อบัญชีก่อนนะคะ")
        return
      end
      user = social.spree_user
      points = user.public_metadata&.dig('shopify_points') || 0
      LineMessagingService.new.send_text(line_user_id, "คะแนนสะสมของคุณ: #{points} คะแนน 🏆")
    end

    def send_order_history(line_user_id)
      social = SocialAccount.find_by(provider: 'line', uid: line_user_id)
      unless social
        LineMessagingService.new.send_text(line_user_id, "กรุณาเชื่อมต่อบัญชีก่อนนะคะ")
        return
      end
      user = social.spree_user
      data = ShopifySyncService.new.sync_customer_orders(email: user.email)
      last = data[:orders]&.first
      if last
        LineMessagingService.new.send_text(
          line_user_id,
          "คำสั่งซื้อล่าสุด: #{last[:order_number]}\nยอด: ฿#{last[:total_price]}\nสถานะ: #{last[:status]}"
        )
      else
        LineMessagingService.new.send_text(line_user_id, "ยังไม่มีประวัติการสั่งซื้อ")
      end
    end

    def valid_signature?(body)
      secret = ENV['LINE_CHANNEL_SECRET']
      return true if secret.blank?

      expected = Base64.strict_encode64(OpenSSL::HMAC.digest('SHA256', secret, body))
      received = request.headers['X-Line-Signature'].to_s
      ActiveSupport::SecurityUtils.secure_compare(expected, received)
    end
  end
end
