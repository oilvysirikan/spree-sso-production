module Api
  module Payments
    class LinePayController < ApplicationController
      skip_before_action :verify_authenticity_token

      # POST /api/payments/line_pay/request
      # Body: { order_id, amount, currency, product_name, confirm_url, cancel_url }
      def request_payment
        required = %w[order_id amount currency product_name confirm_url cancel_url]
        missing = required.reject { |k| params[k].present? }
        return render json: { error: "Missing: #{missing.join(', ')}" }, status: :bad_request if missing.any?

        result = LinePayService.new.request_payment(
          order_id: params[:order_id],
          amount: params[:amount].to_i,
          currency: params[:currency],
          product_name: params[:product_name],
          confirm_url: params[:confirm_url],
          cancel_url: params[:cancel_url]
        )

        if result[:success]
          render json: result
        else
          render json: { error: result[:error], code: result[:code] }, status: :unprocessable_entity
        end
      end

      # POST /api/payments/line_pay/confirm
      # Body: { transaction_id, amount, currency }
      def confirm_payment
        transaction_id = params[:transaction_id]
        return render json: { error: 'transaction_id required' }, status: :bad_request unless transaction_id

        result = LinePayService.new.confirm_payment(
          transaction_id: transaction_id,
          amount: params[:amount].to_i,
          currency: params[:currency] || 'THB'
        )

        if result[:success]
          render json: result
        else
          render json: { error: result[:error], code: result[:code] }, status: :unprocessable_entity
        end
      end

      # GET /api/payments/line_pay/cancel
      def cancel_payment
        render json: { status: 'cancelled', transaction_id: params[:transactionId] }
      end

      # POST /api/payments/line_pay/webhook
      def webhook
        Rails.logger.info "LINE Pay webhook: #{request.body.read}"
        head :ok
      end
    end
  end
end
