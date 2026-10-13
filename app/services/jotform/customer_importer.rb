module Jotform
  # Turns a JotformSubmission into a Spree customer (+ address) for the
  # connection's store.
  #
  # Webhook URLs are reachable by anyone who knows them, so an existing
  # customer's profile is never overwritten: only blank attributes are filled,
  # and the default bill/ship address is only set when the customer has none.
  class CustomerImporter
    class MissingEmail < StandardError; end

    USER_ATTRIBUTES = %w[first_name last_name phone].freeze

    def initialize(submission)
      @submission = submission
      @connection = submission.jotform_connection
      @store = @connection.store
    end

    def call
      values = extract_values
      email = values['email'].to_s.strip.downcase
      raise MissingEmail, 'email is missing from the submission' if email.blank?

      ApplicationRecord.transaction do
        user = find_or_build_user(email)
        USER_ATTRIBUTES.each { |attr| user[attr] = values[attr] if user[attr].blank? && values[attr].present? }
        tag_with_store(user, values['customer_code'])
        user.save!

        attach_address(user, values)
        user
      end
    end

    # Resolves "name.first" against Jotform's rawRequest, where keys look
    # like "q4_name" => { "first" => "...", "last" => "..." }.
    def self.dig_answer(answers, path)
      return if path.blank?

      field, sub = path.to_s.split('.', 2)
      key = answers.keys.find { |k| k == field || k =~ /\Aq\d+_#{Regexp.escape(field)}\z/ }
      return unless key

      value = answers[key]
      value = value[sub] if sub && value.is_a?(Hash)
      value = value.values.reject(&:blank?).join(' ') if value.is_a?(Hash)
      value = value.join(', ') if value.is_a?(Array)
      value.to_s.strip.presence
    end

    private

    attr_reader :submission, :connection, :store

    def extract_values
      connection.mapping.transform_values { |path| self.class.dig_answer(submission.answers, path) }
    end

    def find_or_build_user(email)
      Spree.user_class.find_or_initialize_by(email: email).tap do |user|
        user.password = SecureRandom.base58(32) if user.new_record?
      end
    end

    def tag_with_store(user, customer_code)
      meta = (user.private_metadata || {}).to_h.deep_stringify_keys
      jotform = meta.fetch('jotform', {})
      store_codes = Array(jotform['store_codes']) | [store.code]
      customer_codes = jotform.fetch('customer_codes', {})
      customer_codes = customer_codes.merge(store.code => customer_code) if customer_code.present?

      # Build the nested hash before assigning: writing into a stored
      # HashWithIndifferentAccess copies nested hashes, dropping later changes.
      user.private_metadata = meta.merge(
        'jotform' => jotform.merge('store_codes' => store_codes.compact, 'customer_codes' => customer_codes)
      )
    end

    def attach_address(user, values)
      return if values['address1'].blank?

      country = find_country(values['country'])
      state = country&.states&.find_by('LOWER(name) = :v OR LOWER(abbr) = :v', v: values['state_name'].to_s.downcase)

      address = user.addresses.find_or_initialize_by(
        address1: values['address1'],
        zipcode: values['zipcode'],
        country: country
      )
      if address.new_record?
        address.assign_attributes(
          firstname: values['first_name'] || user.first_name,
          lastname: values['last_name'] || user.last_name,
          address2: values['address2'],
          city: values['city'],
          phone: values['phone'],
          state: state,
          state_name: state ? nil : values['state_name']
        )
        address.save!
      end

      user.update!(bill_address: address) if user.bill_address.nil?
      user.update!(ship_address: address) if user.ship_address.nil?
    end

    def find_country(value)
      fallback = store.default_country
      return fallback if value.blank?

      v = value.to_s.strip
      Spree::Country.where('LOWER(name) = :v OR LOWER(iso) = :v OR LOWER(iso3) = :v', v: v.downcase).first || fallback
    end
  end
end
