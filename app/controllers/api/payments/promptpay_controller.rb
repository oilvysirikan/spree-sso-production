module Api
  module Payments
    class PromptpayController < ApplicationController
      skip_before_action :verify_authenticity_token

      # POST /api/payments/promptpay/create_qr
      # Body: { amount_thb, description, metadata }
      # amount_thb: decimal e.g. 100.00 (will be converted to satang)
      def create_qr
        return render json: { error: 'amount_thb is required' }, status: :bad_request unless params[:amount_thb].present?

        amount_satang = (params[:amount_thb].to_f * 100).round

        if amount_satang < 100  # minimum 1 THB
          return render json: { error: 'Minimum amount is 1 THB' }, status: :bad_request
        end

        result = PromptpayService.new.create_qr(
          amount: amount_satang,
          description: params[:description],
          metadata: params[:metadata]&.to_unsafe_h || {}
        )

        if result[:success]
          render json: result
        else
          render json: { error: result[:error] }, status: :unprocessable_entity
        end
      end

      # GET /api/payments/promptpay/status/:id
      def status
        result = PromptpayService.new.check_status(params[:id])

        if result[:success]
          render json: result
        else
          render json: { error: result[:error] }, status: :not_found
        end
      end

      # POST /api/payments/promptpay/webhook
      # Omise sends payment confirmations here
      def webhook
        payload = JSON.parse(request.body.read)
        Rails.logger.info "Omise webhook event: #{payload['key']} charge: #{payload.dig('data', 'id')}"

        if payload['key'] == 'charge.complete'
          charge_id = payload.dig('data', 'id')
          paid = payload.dig('data', 'paid')
          Rails.logger.info "PromptPay charge #{charge_id} paid=#{paid}"
          # TODO: update Spree order payment status here
        end

        head :ok
      rescue JSON::ParserError
        head :bad_request
      end
    end
  end
end
