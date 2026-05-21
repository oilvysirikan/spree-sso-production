module Api
  class SidekickController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_admin!
    protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format.json? }

    def chat
      message = params[:message]
      
      # สร้าง chat session
      session = ChatSession.create(
        user_id: current_spree_user.id,
        status: 'active'
      )
      
      # บันทึก user message
      ChatMessage.create(
        chat_session_id: session.id,
        role: 'user',
        content: message
      )
      
      # ส่งงานให้ Sidekiq ทำงาน background
      SidekickJob.perform_async(message, current_spree_user.id, session.id)
      
      # response กลับทันที (ไม่ต้องรอ)
      render json: {
        session_id: session.id,
        status: 'processing',
        message: 'กำลังคิดคำตอบให้คุณค่ะ... 🤔'
      }
    end
    
    def check_status
      session = ChatSession.find(params[:session_id])
      last_message = session.messages.where(role: 'assistant').last
      
      render json: {
        status: session.status,
        response: last_message&.content,
        completed: session.status == 'completed'
      }
    end

    private

    def authenticate_admin!
      unless spree_current_user&.has_spree_role?('admin')
        render json: { error: 'Unauthorized' }, status: 401
      end
    end

    def current_spree_user
      spree_current_user
    end
  end
end
