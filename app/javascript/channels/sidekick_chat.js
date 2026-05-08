import consumer from "./consumer"

let currentSessionId = null
let pollingInterval = null

document.addEventListener('DOMContentLoaded', () => {
  // สร้าง chat UI อัตโนมัติ
  injectChatUI()
})

function injectChatUI() {
  const chatHTML = `
    <div id="sidekick-chat" style="position: fixed; bottom: 20px; right: 20px; z-index: 9999;">
      <button onclick="window.toggleChat()" style="background: #4a6cf7; color: white; border: none; border-radius: 50%; width: 60px; height: 60px; cursor: pointer; box-shadow: 0 2px 10px rgba(0,0,0,0.2); font-size: 24px;">
        🤖
      </button>
      
      <div id="chat-window" style="display: none; position: absolute; bottom: 70px; right: 0; width: 400px; height: 600px; background: white; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.2); flex-direction: column; border: 1px solid #ddd;">
        <div style="padding: 15px; background: #4a6cf7; color: white; border-radius: 10px 10px 0 0; display: flex; justify-content: space-between; align-items: center;">
          <strong>✨ Sidekick Assistant</strong>
          <button onclick="window.toggleChat()" style="background: none; border: none; color: white; cursor: pointer; font-size: 20px;">✕</button>
        </div>
        
        <div id="chat-messages" style="flex: 1; padding: 15px; overflow-y: auto; height: 480px; background: #f9fafb;">
          <div style="margin-bottom: 10px; text-align: left;">
            <div style="background: #eef2ff; padding: 8px 12px; border-radius: 10px; display: inline-block; max-width: 80%;">
              สวัสดีค่ะ! ฉันคือ Sidekick พร้อมช่วยคุณจัดการร้านค้า 🚀<br>
              ลองพิมพ์ "ช่วยสร้างสินค้า" หรือ "รายงานยอดขาย" ได้เลย!
            </div>
          </div>
        </div>
        
        <div style="padding: 10px; border-top: 1px solid #ddd; background: white; border-radius: 0 0 10px 10px;">
          <div style="display: flex; gap: 10px;">
            <input type="text" id="chat-input" placeholder="พิมพ์คำสั่ง..." 
                   style="flex: 1; padding: 8px; border: 1px solid #ddd; border-radius: 5px;">
            <button onclick="window.sendMessage()" style="background: #4a6cf7; color: white; border: none; border-radius: 5px; padding: 8px 20px; cursor: pointer;">
              ส่ง
            </button>
          </div>
        </div>
      </div>
    </div>
  `;
  
  document.body.insertAdjacentHTML('beforeend', chatHTML);
}

window.toggleChat = function() {
  const window = document.getElementById('chat-window');
  window.style.display = window.style.display === 'none' ? 'flex' : 'none';
}

window.sendMessage = async function() {
  const input = document.getElementById('chat-input');
  const message = input.value.trim();
  if (!message) return;
  
  addMessage(message, 'user');
  input.value = '';
  
  // แสดง loading
  const loadingId = addLoadingMessage();
  
  try {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    
    const response = await fetch('/api/sidekick/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken || ''
      },
      body: JSON.stringify({ message: message })
    });
    
    const data = await response.json();
    currentSessionId = data.session_id;
    
    startPolling(currentSessionId, loadingId);
    
  } catch (error) {
    removeLoadingMessage(loadingId);
    addMessage('ขออภัย มีปัญหาในการเชื่อมต่อ กรุณาลองใหม่', 'bot');
    console.error('Error:', error);
  }
}

function startPolling(sessionId, loadingId) {
  let attempts = 0;
  const maxAttempts = 30; // 30 seconds
  
  if (pollingInterval) clearInterval(pollingInterval);
  
  pollingInterval = setInterval(async () => {
    try {
      const response = await fetch(`/api/sidekick/status/${sessionId}`);
      const data = await response.json();
      
      if (data.completed) {
        clearInterval(pollingInterval);
        removeLoadingMessage(loadingId);
        addMessage(data.response, 'bot');
        pollingInterval = null;
      } else if (attempts >= maxAttempts) {
        clearInterval(pollingInterval);
        removeLoadingMessage(loadingId);
        addMessage('ขออภัย ใช้เวลานานเกินไป กรุณาลองใหม่', 'bot');
        pollingInterval = null;
      }
      
      attempts++;
    } catch (error) {
      console.error('Polling error:', error);
    }
  }, 1000);
}

function addMessage(text, sender) {
  const messagesDiv = document.getElementById('chat-messages');
  const messageDiv = document.createElement('div');
  messageDiv.style.marginBottom = '10px';
  messageDiv.style.textAlign = sender === 'user' ? 'right' : 'left';
  
  const bubble = document.createElement('div');
  bubble.style.display = 'inline-block';
  bubble.style.padding = '8px 12px';
  bubble.style.borderRadius = '10px';
  bubble.style.maxWidth = '80%';
  bubble.style.background = sender === 'user' ? '#4a6cf7' : '#e5e7eb';
  bubble.style.color = sender === 'user' ? 'white' : 'black';
  bubble.textContent = text;
  
  messageDiv.appendChild(bubble);
  messagesDiv.appendChild(messageDiv);
  messagesDiv.scrollTop = messagesDiv.scrollHeight;
}

function addLoadingMessage() {
  const messagesDiv = document.getElementById('chat-messages');
  const id = 'loading-' + Date.now();
  
  const loadingDiv = document.createElement('div');
  loadingDiv.id = id;
  loadingDiv.style.marginBottom = '10px';
  loadingDiv.style.textAlign = 'left';
  loadingDiv.innerHTML = `
    <div style="background: #e5e7eb; padding: 8px 12px; border-radius: 10px; display: inline-block;">
      🤖 <span class="loading-dots">กำลังคิด</span>
    </div>
  `;
  
  messagesDiv.appendChild(loadingDiv);
  messagesDiv.scrollTop = messagesDiv.scrollHeight;
  
  // animate dots
  let dots = 0;
  const span = loadingDiv.querySelector('.loading-dots');
  const interval = setInterval(() => {
    dots = (dots + 1) % 4;
    span.textContent = 'กำลังคิด' + '.'.repeat(dots);
  }, 500);
  
  loadingDiv.dataset.interval = interval;
  
  return id;
}

function removeLoadingMessage(id) {
  const element = document.getElementById(id);
  if (element) {
    if (element.dataset.interval) {
      clearInterval(parseInt(element.dataset.interval));
    }
    element.remove();
  }
}
