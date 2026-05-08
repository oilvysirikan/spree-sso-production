class SidekickJob
  include Sidekiq::Job
  sidekiq_options retry: 3, queue: 'default'

  def perform(message, user_id, chat_session_id)
    # สร้าง record ว่า AI กำลังคิด
    update_chat_status(chat_session_id, 'processing')
    
    begin
      # เรียก AI Service
      sidekick = SidekickService.new
      context = fetch_context(user_id)
      response = sidekick.chat(message, context)
      
      # บันทึก response
      save_response(chat_session_id, response)
      update_chat_status(chat_session_id, 'completed')
      
      # ส่ง notification ผ่าน WebSocket หรือ Action Cable
      notify_user(chat_session_id, response)
      
    rescue => e
      # จัดการ error
      error_message = "ขออภัย มีปัญหา: #{e.message}"
      save_response(chat_session_id, error_message)
      update_chat_status(chat_session_id, 'failed')
      notify_user(chat_session_id, error_message)
      
      # Log error
      Rails.logger.error "SidekickJob failed: #{e.message}"
    end
  end

  private

  def fetch_context(user_id)
    admin_user = Spree::AdminUser.find(user_id)
    store = admin_user.stores.first || Spree::Store.default
    
    {
      store_name: store.name,
      total_products: Spree::Product.count,
      today_orders: Spree::Order.completed.where('created_at >= ?', Time.current.beginning_of_day).count,
      user_email: admin_user.email
    }
  end

  def update_chat_status(chat_session_id, status)
    # ถ้ามี ChatSession model
    if defined?(ChatSession)
      ChatSession.find(chat_session_id).update(status: status)
    end
  end

  def save_response(chat_session_id, response)
    if defined?(ChatMessage)
      ChatMessage.create(
        chat_session_id: chat_session_id,
        role: 'assistant',
        content: response
      )
    end
  end

  def notify_user(chat_session_id, response)
    # ส่งผ่าน Action Cable
    ActionCable.server.broadcast(
      "chat_#{chat_session_id}",
      { response: response, status: 'completed' }
    )
  end
end
