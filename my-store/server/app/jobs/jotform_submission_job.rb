class JotformSubmissionJob < ApplicationJob
  queue_as :default

  # Solid Queue does not retry on its own. Handlers declared later win, so
  # discard_on below takes precedence over this for MissingEmail.
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  # A submission without an email will never succeed, so don't retry it.
  discard_on Jotform::CustomerImporter::MissingEmail do |job, error|
    JotformSubmission.find_by(id: job.arguments.first)
                     &.update!(status: 'failed', error_message: error.message, processed_at: Time.current)
  end

  def perform(submission_id)
    submission = JotformSubmission.find_by(id: submission_id)
    return if submission.nil? || submission.status == 'processed'

    importer = Jotform::CustomerImporter.new(submission)
    customer = importer.call
    submission.update!(status: 'processed', spree_customer: customer,
                       error_message: importer.warnings.join('; ').presence, processed_at: Time.current)
  rescue Jotform::CustomerImporter::MissingEmail
    raise
  rescue StandardError => e
    # Record the failure for the admin; retry_on schedules the next attempt.
    submission&.update_columns(status: 'failed', error_message: "#{e.class}: #{e.message}".truncate(1000), updated_at: Time.current)
    raise
  end
end
