module Api
  # Receives Jotform webhooks. Each store gets its own URL:
  #   POST /api/jotform/webhook/:token
  #
  # The request is only validated and stored here; turning it into a Spree
  # customer happens in JotformSubmissionJob so Jotform gets a fast 200.
  class JotformController < ActionController::API
    # POST /api/jotform/webhook/:token
    def webhook
      connection = JotformConnection.active.find_by(token: params[:token].to_s)
      return head :not_found unless connection
      return head :forbidden unless connection.form_matches?(params[:formID])

      submission_id = params[:submissionID].presence
      answers = parse_raw_request(params[:rawRequest])
      return render(json: { error: 'submissionID and rawRequest are required' }, status: :unprocessable_content) unless submission_id && answers

      submission = connection.submissions.create!(
        submission_id: submission_id,
        payload: { 'form_id' => params[:formID].to_s, 'answers' => answers }
      )
      JotformSubmissionJob.perform_later(submission.id)

      render json: { status: 'accepted' }, status: :ok
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      raise unless duplicate?(e)

      render json: { status: 'duplicate' }, status: :ok
    end

    private

    def parse_raw_request(raw)
      parsed = JSON.parse(raw.to_s)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    def duplicate?(error)
      return true if error.is_a?(ActiveRecord::RecordNotUnique)

      error.record.errors.of_kind?(:submission_id, :taken)
    end
  end
end
