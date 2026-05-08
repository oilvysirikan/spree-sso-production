class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:session_id]}"
  end

  def unsubscribed
    # cleanup
  end
end
