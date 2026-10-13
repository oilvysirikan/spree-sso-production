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

  def mapping
    DEFAULT_FIELD_MAPPING.merge(field_mapping.to_h.stringify_keys)
  end

  def form_matches?(incoming_form_id)
    form_id.blank? || form_id.to_s == incoming_form_id.to_s
  end

  def webhook_path
    "/api/jotform/webhook/#{token}"
  end

  private

  def field_mapping_keys_are_known
    unknown = field_mapping.to_h.keys.map(&:to_s) - DEFAULT_FIELD_MAPPING.keys
    errors.add(:field_mapping, "has unknown keys: #{unknown.join(', ')}") if unknown.any?
  end
end
