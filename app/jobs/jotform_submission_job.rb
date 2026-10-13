class JotformSubmissionJob < ApplicationJob
  queue_as :default

  # A submission without an email will never succeed, so don't retry it.
  discard_on Jotform::CustomerImporter::MissingEmail do |job, error|
    JotformSubmission.find_by(id: job.arguments.first)
                     &.update!(status: 'failed', error_message: error.message, processed_at: Time.current)
  end

  def perform(submission_id)
    submission = JotformSubmission.find_by(id: submission_id)
    return if submission.nil? || submission.status == 'processed'

    user = Jotform::CustomerImporter.new(submission).call
    submission.update!(status: 'processed', spree_user: user, error_message: nil, processed_at: Time.current)
  rescue Jotform::CustomerImporter::MissingEmail
    raise
  rescue StandardError => e
    # Record the failure for the admin, then let Sidekiq retry.
    submission&.update_columns(status: 'failed', error_message: "#{e.class}: #{e.message}".truncate(1000), updated_at: Time.current)
    raise
  end
end
