module Api
  class ShopifyController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_shopify_webhook, only: [:webhook]

    # POST /api/shopify/sync_products
    def sync_products
      limit = (params[:limit] || 50).to_i
      result = ShopifySyncService.new.sync_products(limit: limit)
      render json: { success: true, result: result }
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    # POST /api/shopify/sync_orders
    def sync_orders
      result = ShopifySyncService.new.sync_orders(
        limit: (params[:limit] || 50).to_i,
        since_id: params[:since_id]
      )
      render json: { success: true, result: result }
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    # POST /api/shopify/webhook
    def webhook
      payload = JSON.parse(request.body.read)
      topic = request.headers['X-Shopify-Topic']
      Rails.logger.info "Shopify webhook: #{topic}"

      case topic
      when 'orders/paid'
        handle_order_paid(payload)
      when 'products/update', 'products/create'
        handle_product_update(payload)
      when 'inventory_levels/update'
        handle_inventory_update(payload)
      end

      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    # GET /api/shopify/status
    def status
      render json: {
        configured: ENV['SHOPIFY_SHOP_DOMAIN'].present? && ENV['SHOPIFY_ACCESS_TOKEN'].present?,
        shop_domain: ENV['SHOPIFY_SHOP_DOMAIN']
      }
    end

    private

    def handle_order_paid(order)
      email = order.dig('customer', 'email')
      return unless email

      user = Spree::User.find_by(email: email)
      return unless user

      # Award points — recalculate from all Shopify orders
      sync_result = ShopifySyncService.new.sync_customer_orders(email: email)
      user.public_metadata ||= {}
      user.public_metadata['shopify_points'] = sync_result[:points]
      user.public_metadata['shopify_total_spent'] = sync_result[:total_spent_thb]
      user.save!

      Rails.logger.info "Updated points for #{email}: #{sync_result[:points]} pts"
    end

    def handle_product_update(product)
      Rails.logger.info "Product update from Shopify: #{product['id']} #{product['title']}"
      # Sync updated product to Spree
      ShopifySyncService.new.sync_products(limit: 1) rescue nil
    end

    def handle_inventory_update(payload)
      # Check if product is back in stock and notify customers
      inventory_item_id = payload['inventory_item_id']
      available = payload['available'].to_i
      return unless available > 0

      Rails.logger.info "Back in stock: inventory_item #{inventory_item_id}, qty=#{available}"
      # LineNotifyService handles sending back-in-stock alerts
    end

    def verify_shopify_webhook
      secret = ENV['SHOPIFY_WEBHOOK_SECRET']
      return if secret.blank?

      hmac_header = request.headers['X-Shopify-Hmac-Sha256']
      body = request.body.read
      request.body.rewind

      digest = Base64.strict_encode64(OpenSSL::HMAC.digest('SHA256', secret, body))
      unless ActiveSupport::SecurityUtils.secure_compare(digest, hmac_header.to_s)
        render json: { error: 'Invalid signature' }, status: :unauthorized
      end
    end
  end
end
