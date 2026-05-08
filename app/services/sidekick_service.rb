require 'gemini-ai'

class SidekickService
  def initialize
    # Version 1: ใช้แบบพื้นฐานก่อน
    @api_key = ENV['GEMINI_API_KEY']
  end

  def chat(message, context = {})
    # Version 1: ตอบกลับแบบง่ายๆ ก่อน
    simple_response(message, context)
  end

  private

  def simple_response(message, context)
    response_text = "คุณพูดว่า: '#{message}'\n\n📍 ร้าน: #{context[:store_name]}\n📦 สินค้า: #{context[:total_products]} รายการ\nกำลังพัฒนาให้ตอบฉลาดขึ้นในเวอร์ชันหน้าครับ! 🚀"
    
    # บันทึก response ลง chat history ถ้ามี session
    response_text
  end
end
