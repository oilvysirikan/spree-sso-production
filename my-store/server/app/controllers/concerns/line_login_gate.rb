# LINE Login and the /member portal are switched off.
#
# The code merged in PR #12 does not work on Spree 6 yet (wrong foreign key,
# `public_metadata`, orders by `user_id`) and links LINE accounts to existing
# customers by email without a verified-email check. Until that is fixed and
# tested, every action answers 404 before any other callback runs: no call to
# LINE, no customer/SocialAccount writes, no session changes.
#
# This is deliberately a code constant, not an env var: flipping a setting
# must not be able to expose code that is known to be broken.
module LineLoginGate
  extend ActiveSupport::Concern

  ENABLED = false

  included do
    prepend_before_action :reject_while_line_login_disabled
  end

  private

  def reject_while_line_login_disabled
    head :not_found unless ENABLED
  end
end
