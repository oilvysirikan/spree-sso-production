require 'csv'

module Api
  # Read-only list of received Jotform submissions, for forms that only store
  # data (no Spree customers) and for checking the webhook works.
  #   GET /api/jotform/submissions        JSON
  #   GET /api/jotform/submissions.csv    CSV (opens in Excel / Google Sheets)
  #
  # Uses the same HTTP Basic credentials as the /jobs dashboard
  # (MISSION_CONTROL_USER / MISSION_CONTROL_PASSWORD); without them it denies.
  class JotformSubmissionsController < ActionController::API
    include ActionController::HttpAuthentication::Basic::ControllerMethods

    LIMIT = 500

    before_action :authenticate

    def index
      submissions = JotformSubmission.includes(jotform_connection: :store).order(created_at: :desc).limit(LIMIT)
      submissions = submissions.where(status: params[:status]) if JotformSubmission::STATUSES.include?(params[:status])

      if request.format.csv?
        send_data to_csv(submissions), filename: "jotform-submissions-#{Date.current}.csv", type: 'text/csv; charset=utf-8'
      else
        render json: submissions.map { |s| serialize(s) }
      end
    end

    private

    def authenticate
      user = Rails.application.config.mission_control.jobs.http_basic_auth_user
      password = Rails.application.config.mission_control.jobs.http_basic_auth_password
      return head(:not_found) if user.blank? || password.blank?

      authenticate_or_request_with_http_basic('Jotform submissions') do |u, p|
        ActiveSupport::SecurityUtils.secure_compare(u, user) & ActiveSupport::SecurityUtils.secure_compare(p, password)
      end
    end

    def serialize(submission)
      {
        submission_id: submission.submission_id,
        store: submission.jotform_connection.store.code,
        form_id: submission.payload['form_id'],
        status: submission.status,
        error: submission.error_message,
        received_at: submission.created_at.iso8601,
        pretty: submission.pretty,
        answers: submission.answers
      }
    end

    def to_csv(submissions)
      # BOM so Excel opens Thai text as UTF-8.
      "﻿" + CSV.generate do |csv|
        csv << %w[received_at submission_id store status pretty error]
        submissions.each do |s|
          csv << [s.created_at.iso8601, s.submission_id, s.jotform_connection.store.code, s.status, s.pretty, s.error_message]
        end
      end
    end
  end
end
