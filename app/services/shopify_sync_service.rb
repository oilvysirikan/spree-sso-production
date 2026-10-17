class ShopifySyncService
  SHOPIFY_API_VERSION = '2024-10'

  def initialize(shop_domain: nil, access_token: nil)
    @shop_domain = shop_domain || ENV['SHOPIFY_SHOP_DOMAIN']
    @access_token = access_token || ENV['SHOPIFY_ACCESS_TOKEN']
    @base_url = "https://#{@shop_domain}/admin/api/#{SHOPIFY_API_VERSION}"
  end

  # Sync all products from Shopify → Spree
  def sync_products(limit: 50)
    products = fetch_shopify_products(limit: limit)
    synced = 0
    errors = []

    products.each do |shopify_product|
      upsert_spree_product(shopify_product)
      synced += 1
    rescue StandardError => e
      errors << { shopify_id: shopify_product['id'], error: e.message }
      Rails.logger.error "Product sync error #{shopify_product['id']}: #{e.message}"
    end

    { synced: synced, errors: errors, total: products.size }
  end

  # Sync orders for a customer by email
  def sync_customer_orders(email:)
    customers = fetch_shopify_customers(email: email)
    return { orders: [], points: 0 } if customers.empty?

    customer = customers.first
    orders = fetch_shopify_orders(customer_id: customer['id'])
    points = calculate_points(orders)

    {
      shopify_customer_id: customer['id'],
      orders: orders.map { |o| format_order(o) },
      total_orders: orders.size,
      total_spent_thb: orders.sum { |o| o['total_price'].to_f }.round(2),
      points: points
    }
  end

  # Sync all orders (admin use)
  def sync_orders(limit: 50, since_id: nil)
    orders = fetch_shopify_orders(limit: limit, since_id: since_id)
    { orders: orders.map { |o| format_order(o) }, total: orders.size }
  end

  private

  def fetch_shopify_products(limit: 50)
    response = api_get('/products.json', { limit: limit, status: 'active' })
    response['products'] || []
  end

  def fetch_shopify_customers(email:)
    response = api_get('/customers/search.json', { query: "email:#{email}", limit: 1 })
    response['customers'] || []
  end

  def fetch_shopify_orders(customer_id: nil, limit: 50, since_id: nil)
    params = { limit: limit, status: 'any' }
    params[:customer_id] = customer_id if customer_id
    params[:since_id] = since_id if since_id
    response = api_get('/orders.json', params)
    response['orders'] || []
  end

  def upsert_spree_product(shopify_product)
    spree_product = Spree::Product.find_or_initialize_by(
      'public_metadata @> ?', { shopify_id: shopify_product['id'].to_s }.to_json
    )

    spree_product.assign_attributes(
      name: shopify_product['title'],
      description: shopify_product['body_html']&.gsub(/<[^>]+>/, ''),
      available_on: shopify_product['published_at']
    )
    spree_product.public_metadata ||= {}
    spree_product.public_metadata['shopify_id'] = shopify_product['id'].to_s
    spree_product.public_metadata['shopify_handle'] = shopify_product['handle']
    spree_product.public_metadata['shopify_vendor'] = shopify_product['vendor']
    spree_product.save!
  end

  def format_order(order)
    {
      shopify_order_id: order['id'],
      order_number: order['name'],
      status: order['financial_status'],
      fulfillment_status: order['fulfillment_status'],
      total_price: order['total_price'].to_f,
      currency: order['currency'],
      created_at: order['created_at'],
      line_items: order['line_items']&.map do |item|
        {
          product_id: item['product_id'],
          title: item['title'],
          quantity: item['quantity'],
          price: item['price'].to_f
        }
      end
    }
  end

  # 1 point per 25 THB spent, only on paid orders
  def calculate_points(orders)
    paid_orders = orders.select { |o| o['financial_status'] == 'paid' }
    total_spent = paid_orders.sum { |o| o['total_price'].to_f }
    (total_spent / 25).floor
  end

  def api_get(path, params = {})
    query_string = params.map { |k, v| "#{k}=#{v}" }.join('&')
    url = "#{@base_url}#{path}"
    url += "?#{query_string}" if query_string.present?

    response = HTTParty.get(
      url,
      headers: {
        'X-Shopify-Access-Token' => @access_token,
        'Content-Type' => 'application/json'
      }
    )
    response.parsed_response
  rescue StandardError => e
    Rails.logger.error "Shopify API Error: #{e.message}"
    {}
  end
end
