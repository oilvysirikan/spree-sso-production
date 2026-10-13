# One Jotform submission received by the webhook. The unique index on
# (jotform_connection_id, submission_id) makes Jotform retries idempotent.
class JotformSubmission < ApplicationRecord
  STATUSES = %w[pending processed failed].freeze

  belongs_to :jotform_connection
  belongs_to :spree_customer, class_name: Spree.customer_class.to_s, optional: true

  validates :submission_id, presence: true, uniqueness: { scope: :jotform_connection_id }
  validates :status, inclusion: { in: STATUSES }

  def answers
    payload.fetch('answers', {})
  end
end
