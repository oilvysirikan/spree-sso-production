module Jotform
  # Turns a JotformSubmission into a Spree customer (+ address) for the
  # connection's store.
  #
  # Webhook URLs are reachable by anyone who knows them, so an existing
  # customer's profile is never overwritten: only blank attributes are filled,
  # and the default bill/ship address is only set when the customer has none.
  # New customers get no password; they claim the account via password reset.
  class CustomerImporter
    class MissingEmail < StandardError; end

    CUSTOMER_ATTRIBUTES = %w[first_name last_name phone].freeze
    TAG = 'jotform'.freeze

    # Problems that did not stop the import (e.g. an address Spree rejected).
    attr_reader :warnings

    def initialize(submission)
      @submission = submission
      @connection = submission.jotform_connection
      @store = @connection.store
      @warnings = []
    end

    def call
      values = extract_values
      email = values['email'].to_s.strip.downcase
      raise MissingEmail, 'email is missing from the submission' if email.blank?

      customer = Spree.customer_class.where('LOWER(email) = ?', email).first || Spree.customer_class.new(email: email)
      CUSTOMER_ATTRIBUTES.each do |attr|
        customer[attr] = values[attr] if customer[attr].blank? && values[attr].present?
      end
      customer.tag_list.add(TAG)
      tag_with_store(customer, values['customer_code'])
      customer.save!

      # A rejected address (e.g. Thailand needs a province Spree recognises)
      # must not lose the customer, so it is saved separately as a warning.
      begin
        attach_address(customer, values)
      rescue ActiveRecord::RecordInvalid => e
        warnings << "address not saved: #{e.record.errors.full_messages.to_sentence}"
      end

      customer
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

    def tag_with_store(customer, customer_code)
      meta = (customer.metadata || {}).to_h.deep_stringify_keys
      jotform = meta.fetch('jotform', {})
      store_codes = Array(jotform['store_codes']) | [store.code]
      customer_codes = jotform.fetch('customer_codes', {})
      customer_codes = customer_codes.merge(store.code => customer_code) if customer_code.present?

      # Build the nested hash before assigning: writing into a stored
      # HashWithIndifferentAccess copies nested hashes, dropping later changes.
      customer.metadata = meta.merge(
        'jotform' => jotform.merge('store_codes' => store_codes.compact, 'customer_codes' => customer_codes)
      )
    end

    def attach_address(customer, values)
      return if values['address1'].blank?

      country_code = resolve_country_code(values['country'])
      address = customer.addresses.find_by(address1: values['address1'], postal_code: values['zipcode'], country_code: country_code)
      address ||= customer.addresses.create!(
        first_name: values['first_name'] || customer.first_name,
        last_name: values['last_name'] || customer.last_name,
        address1: values['address1'],
        address2: values['address2'],
        city: values['city'],
        postal_code: values['zipcode'],
        phone: values['phone'],
        country_code: country_code,
        state_name: values['state_name']
      )

      updates = {}
      updates[:bill_address] = address if customer.bill_address.nil?
      updates[:ship_address] = address if customer.ship_address.nil?
      customer.update!(updates) if updates.any?
    end

    # Jotform's address field sends the country's English name ("Thailand");
    # Spree 6 stores ISO codes. Falls back to the store's default country.
    def resolve_country_code(value)
      v = value.to_s.strip
      country = Spree::Country.by_iso(v) if v.length.between?(2, 3)
      country ||= Spree::Country.all.find { |c| c.name.to_s.casecmp?(v) } if v.present?
      country ||= store.default_country
      country&.iso
    end
  end
end
