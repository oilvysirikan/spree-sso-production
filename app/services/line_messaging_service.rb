class LineMessagingService
  LINE_API_BASE = 'https://api.line.me/v2/bot'

  def initialize
    @channel_token = ENV['LINE_CHANNEL_ACCESS_TOKEN']
  end

  # Send a push message to a LINE user (by LINE user ID)
  def push_message(line_user_id, messages)
    messages = [messages] unless messages.is_a?(Array)
    post('/message/push', {
      to: line_user_id,
      messages: messages
    })
  end

  # Send text message
  def send_text(line_user_id, text)
    push_message(line_user_id, { type: 'text', text: text })
  end

  # Back-in-stock alert with product button
  def send_back_in_stock_alert(line_user_id, product_name:, product_url:, image_url: nil)
    message = {
      type: 'template',
      altText: "#{product_name} กลับมามีสินค้าแล้ว!",
      template: {
        type: 'buttons',
        thumbnailImageUrl: image_url,
        title: 'สินค้ากลับมาแล้ว!',
        text: "#{product_name} มีสินค้าพร้อมส่งแล้ว อย่าพลาดนะคะ",
        actions: [
          { type: 'uri', label: 'ดูสินค้า', uri: product_url },
          { type: 'uri', label: 'สั่งซื้อเลย', uri: product_url }
        ]
      }.compact
    }
    push_message(line_user_id, message)
  end

  # Order confirmation message with Flex bubble
  def send_order_confirmation(line_user_id, order_number:, total:, items: [])
    body_contents = [
      { type: 'text', text: "คำสั่งซื้อ #{order_number}", weight: 'bold', size: 'md' },
      { type: 'separator', margin: 'md' }
    ]

    items.each do |item|
      body_contents << {
        type: 'box', layout: 'horizontal',
        contents: [
          { type: 'text', text: item[:name], size: 'sm', color: '#555555', flex: 4 },
          { type: 'text', text: "฿#{item[:price]}", size: 'sm', color: '#111111', align: 'end', flex: 2 }
        ]
      }
    end

    body_contents += [
      { type: 'separator', margin: 'md' },
      { type: 'box', layout: 'horizontal', margin: 'md', contents: [
        { type: 'text', text: 'ยอดรวม', size: 'sm', weight: 'bold', flex: 4 },
        { type: 'text', text: "฿#{total}", size: 'sm', weight: 'bold', align: 'end', flex: 2, color: '#E8502A' }
      ]}
    ]

    message = {
      type: 'flex',
      altText: "ยืนยันคำสั่งซื้อ #{order_number}",
      contents: {
        type: 'bubble',
        header: {
          type: 'box', layout: 'vertical', backgroundColor: '#E8502A',
          contents: [{ type: 'text', text: 'ยืนยันคำสั่งซื้อ', color: '#FFFFFF', weight: 'bold' }]
        },
        body: { type: 'box', layout: 'vertical', contents: body_contents }
      }
    }
    push_message(line_user_id, message)
  end

  # Send loyalty points update
  def send_points_update(line_user_id, points:, earned:, order_number:)
    text = "🎉 ออเดอร์ #{order_number} สำเร็จแล้ว!\n" \
           "คุณได้รับ +#{earned} คะแนน\n" \
           "คะแนนสะสมทั้งหมด: #{points} คะแนน"
    send_text(line_user_id, text)
  end

  # Multicast — send to many users at once (up to 500)
  def multicast(line_user_ids, messages)
    messages = [messages] unless messages.is_a?(Array)
    line_user_ids.each_slice(500) do |batch|
      post('/message/multicast', { to: batch, messages: messages })
    end
  end

  # Set rich menu for a user
  def link_rich_menu(line_user_id, rich_menu_id)
    HTTParty.post(
      "#{LINE_API_BASE}/user/#{line_user_id}/richmenu/#{rich_menu_id}",
      headers: auth_headers.except('Content-Type')
    )
  end

  private

  def post(path, body)
    response = HTTParty.post(
      "#{LINE_API_BASE}#{path}",
      headers: auth_headers,
      body: body.to_json
    )
    unless response.success?
      Rails.logger.error "LINE Messaging error #{response.code}: #{response.body}"
    end
    response.parsed_response
  end

  def auth_headers
    {
      'Authorization' => "Bearer #{@channel_token}",
      'Content-Type' => 'application/json'
    }
  end
end
