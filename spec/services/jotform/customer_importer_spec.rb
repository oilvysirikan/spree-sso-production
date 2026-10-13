require 'rails_helper'

RSpec.describe Jotform::CustomerImporter do
  describe '.dig_answer' do
    let(:answers) do
      {
        'q3_email' => 'a@b.co',
        'q4_name' => { 'first' => 'Somchai', 'last' => 'Jaidee' },
        'q5_phoneNumber' => { 'area' => '081', 'phone' => '2345678' },
        'q8_interests' => %w[Shoes Bags],
        'plain' => 'value'
      }
    end

    it { expect(described_class.dig_answer(answers, 'email')).to eq('a@b.co') }
    it { expect(described_class.dig_answer(answers, 'q3_email')).to eq('a@b.co') }
    it { expect(described_class.dig_answer(answers, 'name.first')).to eq('Somchai') }
    it { expect(described_class.dig_answer(answers, 'phoneNumber')).to eq('081 2345678') }
    it { expect(described_class.dig_answer(answers, 'interests')).to eq('Shoes, Bags') }
    it { expect(described_class.dig_answer(answers, 'plain')).to eq('value') }
    it { expect(described_class.dig_answer(answers, 'missing')).to be_nil }
    it { expect(described_class.dig_answer(answers, 'name.middle')).to be_nil }
    it 'does not match a field whose name only ends with the path' do
      expect(described_class.dig_answer({ 'q2_workEmail' => 'x' }, 'email')).to be_nil
    end
  end
end
