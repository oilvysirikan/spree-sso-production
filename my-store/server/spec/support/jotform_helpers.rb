module JotformHelpers
  def jotform_answers(overrides = {})
    {
      'q3_email' => 'Somchai@Example.com',
      'q4_name' => { 'first' => 'Somchai', 'last' => 'Jaidee' },
      'q5_phoneNumber' => { 'full' => '081-234-5678' },
      'q6_address' => {
        'addr_line1' => '99 Sukhumvit Rd',
        'addr_line2' => 'Unit 5',
        'city' => 'Bangkok',
        'state' => '',
        'postal' => '10110',
        'country' => ''
      },
      'q7_customerCode' => 'CUST-001'
    }.merge(overrides)
  end
end

RSpec.configure do |config|
  config.include JotformHelpers
end

RSpec::Matchers.define_negated_matcher :not_change, :change unless RSpec::Matchers.method_defined?(:not_change)
RSpec::Matchers.define_negated_matcher :not_have_enqueued_job, :have_enqueued_job unless RSpec::Matchers.method_defined?(:not_have_enqueued_job)
