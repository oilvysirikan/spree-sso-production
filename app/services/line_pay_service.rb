class LinePayService
  BASE_URL = ENV.fetch('LINE_PAY_ENV', 'sandbox') == 'production' \
    ? 'https://api-pay.line.me'
    : 'https://sandbox-api-pay.line.me'

  def initialize
    @channel_id = ENV['LINE_PAY_CHANNEL_ID']
    @channel_secret = ENV['LINE_PAY_CHANNEL_SECRET']
  end

  def request_payment(order_id:, amount:, currency:, product_name:, confirm_url:, cancel_url:)
    body = {
      amount: amount,
      currency: currency,
      orderId: order_id,
      packages: [
        {
          id: "pkg_#{order_id}",
          amount: amount,
          products: [{ name: product_name, quantity: 1, price: amount }]
        }
      ],
      redirectUrls: {
        confirmUrl: confirm_url,
        cancelUrl: cancel_url
      }
    }.to_json

    path = '/v3/payments/request'
    response = call_api(:post, path, body)

    if response['returnCode'] == '0000'
      {
        success: true,
        transaction_id: response.dig('info', 'transactionId'),
        payment_url: response.dig('info', 'paymentUrl', 'web'),
        payment_url_app: response.dig('info', 'paymentUrl', 'app')
      }
    else
      { success: false, error: response['returnMessage'], code: response['returnCode'] }
    end
  end

  def confirm_payment(transaction_id:, amount:, currency:)
    body = { amount: amount, currency: currency }.to_json
    path = "/v3/payments/#{transaction_id}/confirm"
    response = call_api(:post, path, body)

    if response['returnCode'] == '0000'
      info = response['info']
      {
        success: true,
        transaction_id: info['transactionId'],
        order_id: info['orderId'],
        payment_type: info.dig('payInfo', 0, 'method'),
        amount: info.dig('payInfo', 0, 'amount')
      }
    else
      { success: false, error: response['returnMessage'], code: response['returnCode'] }
    end
  end

  def payment_status(transaction_id)
    path = '/v3/payments'
    response = call_api(:get, "#{path}?transactionId=#{transaction_id}", nil)

    if response['returnCode'] == '0000'
      { success: true, data: response['info'] }
    else
      { success: false, error: response['returnMessage'] }
    end
  end

  private

  def call_api(method, path, body)
    nonce = SecureRandom.hex(8)
    timestamp = (Time.current.to_f * 1000).to_i.to_s

    message = "#{@channel_secret}#{path}#{body}#{nonce}#{timestamp}"
    signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest('SHA256', @channel_secret, message)
    )

    headers = {
      'Content-Type' => 'application/json',
      'X-LINE-ChannelId' => @channel_id,
      'X-LINE-Authorization-Nonce' => nonce,
      'X-LINE-Authorization' => signature,
      'X-LINE-Authorization-Time' => timestamp
    }

    url = "#{BASE_URL}#{path}"
    response = if method == :post
      HTTParty.post(url, body: body, headers: headers)
    else
      HTTParty.get(url, headers: headers)
    end

    response.parsed_response
  rescue StandardError => e
    Rails.logger.error "LINE Pay API Error: #{e.message}"
    { 'returnCode' => 'ERROR', 'returnMessage' => e.message }
  end
end
