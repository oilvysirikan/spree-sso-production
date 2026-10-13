# Links one Spree store to one Jotform form.
#
# Jotform does not sign webhook requests, so the long random +token+ in the
# webhook URL is the shared secret. The +form_id+ (when set) is checked against
# the formID Jotform sends, so a leaked URL can't be reused from another form.
class JotformConnection < ApplicationRecord
  # Keys are Spree customer attributes, values are Jotform field paths.
  # A path is the field's unique name (the "q3_" prefix is optional) with
  # sub-fields after a dot, e.g. "name.first" or "phoneNumber.full".
  DEFAULT_FIELD_MAPPING = {
    'email' => 'email',
    'first_name' => 'name.first',
    'last_name' => 'name.last',
    'phone' => 'phoneNumber.full',
    'address1' => 'address.addr_line1',
    'address2' => 'address.addr_line2',
    'city' => 'address.city',
    'state_name' => 'address.state',
    'zipcode' => 'address.postal',
    'country' => 'address.country',
    'customer_code' => 'customerCode'
  }.freeze

  belongs_to :store, class_name: 'Spree::Store'
  has_many :submissions, class_name: 'JotformSubmission', dependent: :destroy

  has_secure_token :token, length: 40

  validates :form_id, uniqueness: { scope: :store_id }, allow_blank: true
  validate :field_mapping_keys_are_known

  scope :active, -> { where(active: true) }

  # Production runs on Render's free plan (no shell), so the first store's
  # connection is configured with env vars instead of the rake task:
  #   JOTFORM_STORE          store code or prefixed id (store_UkLWZg9DAJ)
  #   JOTFORM_FORM_ID        Jotform form id (optional but recommended)
  #   JOTFORM_WEBHOOK_TOKEN  long random secret used in the webhook URL
  # The row is created the first time Jotform calls the matching URL.
  def self.find_for_webhook(token)
    return if token.blank?

    active.find_by(token: token) || create_from_env(token)
  end

  def self.create_from_env(token)
    env_token = ENV['JOTFORM_WEBHOOK_TOKEN'].to_s
    return if env_token.length < 32 || !ActiveSupport::SecurityUtils.secure_compare(token, env_token)
    return if exists?(token: env_token) # present but deactivated

    store = find_store(ENV['JOTFORM_STORE'].to_s)
    return unless store

    create!(store: store, form_id: ENV['JOTFORM_FORM_ID'].presence, token: env_token, name: 'env')
  rescue ActiveRecord::RecordNotUnique
    active.find_by(token: env_token)
  end

  def self.find_store(ref)
    return if ref.blank?

    Spree::Store.find_by(code: ref) || Spree::Store.find_by_prefix_id(ref)
  end

  def mapping
    DEFAULT_FIELD_MAPPING.merge(field_mapping.to_h.stringify_keys)
  end

  def form_matches?(incoming_form_id)
    form_id.blank? || form_id.to_s == incoming_form_id.to_s
  end

  def webhook_path
    "/api/jotform/webhook?token=#{token}"
  end

  private

  def field_mapping_keys_are_known
    unknown = field_mapping.to_h.keys.map(&:to_s) - DEFAULT_FIELD_MAPPING.keys
    errors.add(:field_mapping, "has unknown keys: #{unknown.join(', ')}") if unknown.any?
  end
end
