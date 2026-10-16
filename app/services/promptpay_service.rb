class PromptpayService
  OMISE_BASE_URL = 'https://api.omise.co'

  def initialize
    @secret_key = ENV['OMISE_SECRET_KEY']
    @public_key = ENV['OMISE_PUBLIC_KEY']
  end

  # Creates a PromptPay charge and returns QR code data
  # amount is in satang (smallest unit) — 10000 satang = 100 THB
  def create_qr(amount:, description: nil, metadata: {})
    source_result = create_promptpay_source(amount)
    return source_result unless source_result[:success]

    charge_result = create_charge(
      amount: amount,
      source_id: source_result[:source_id],
      description: description,
      metadata: metadata
    )
    return charge_result unless charge_result[:success]

    {
      success: true,
      charge_id: charge_result[:charge_id],
      amount: amount,
      amount_thb: (amount / 100.0).round(2),
      status: charge_result[:status],
      qr_code_url: charge_result[:qr_code_url],
      expires_at: charge_result[:expires_at]
    }
  end

  def check_status(charge_id)
    response = api_get("/charges/#{charge_id}")

    if response['object'] == 'charge'
      {
        success: true,
        charge_id: response['id'],
        status: response['status'],
        paid: response['paid'],
        amount: response['amount'],
        amount_thb: (response['amount'] / 100.0).round(2)
      }
    else
      { success: false, error: response['message'] || 'Charge not found' }
    end
  end

  private

  def create_promptpay_source(amount)
    response = api_post('/sources', {
      type: 'promptpay',
      amount: amount,
      currency: 'THB'
    })

    if response['object'] == 'source'
      { success: true, source_id: response['id'] }
    else
      { success: false, error: response['message'] }
    end
  end

  def create_charge(amount:, source_id:, description:, metadata:)
    body = {
      amount: amount,
      currency: 'THB',
      source: source_id,
      return_uri: ENV['OMISE_RETURN_URI'] || "#{ENV['APP_URL']}/api/payments/promptpay/return"
    }
    body[:description] = description if description.present?
    body[:metadata] = metadata if metadata.present?

    response = api_post('/charges', body)

    if response['object'] == 'charge'
      {
        success: true,
        charge_id: response['id'],
        status: response['status'],
        qr_code_url: response.dig('source', 'scannable_code', 'image', 'download_uri'),
        expires_at: response['expires_at']
      }
    else
      { success: false, error: response['message'] }
    end
  end

  def api_post(path, body)
    HTTParty.post(
      "#{OMISE_BASE_URL}#{path}",
      basic_auth: { username: @secret_key, password: '' },
      headers: { 'Content-Type' => 'application/json' },
      body: body.to_json
    ).parsed_response
  rescue StandardError => e
    Rails.logger.error "Omise API Error: #{e.message}"
    { 'object' => 'error', 'message' => e.message }
  end

  def api_get(path)
    HTTParty.get(
      "#{OMISE_BASE_URL}#{path}",
      basic_auth: { username: @secret_key, password: '' }
    ).parsed_response
  rescue StandardError => e
    Rails.logger.error "Omise API Error: #{e.message}"
    { 'object' => 'error', 'message' => e.message }
  end
end
