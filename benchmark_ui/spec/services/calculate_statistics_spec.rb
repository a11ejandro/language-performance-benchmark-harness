require 'spec_helper'
require_relative '../../app/services/calculate_statistics'

RSpec.describe CalculateStatistics do
  describe '.call' do
    it 'returns an empty hash for no samples' do
      expect(described_class.call([])).to eq({})
    end

    it 'computes stats for a single value' do
      result = described_class.call([42])
      expect(result[:min]).to eq 42
      expect(result[:max]).to eq 42
      expect(result[:median]).to eq 42
      expect(result[:mean]).to eq 42.0
      expect(result[:q1]).to eq 42
      expect(result[:q3]).to eq 42
      expect(result[:standard_deviation]).to eq 0.0
    end

    it 'computes stats for an even-sized set (unsorted input)' do
      samples = [4, 1, 3, 2]
      result = described_class.call(samples)

      expect(result[:min]).to eq 1
      expect(result[:max]).to eq 4
      expect(result[:median]).to eq 2.5
      expect(result[:mean]).to eq 2.5
      expect(result[:q1]).to eq 1
      expect(result[:q3]).to eq 3
      # population standard deviation
      expect(result[:standard_deviation]).to be_within(1e-10).of(Math.sqrt(1.25))
    end

    it 'computes stats for an odd-sized set' do
      samples = [1, 2, 3, 4, 5]
      result = described_class.call(samples)

      expect(result[:min]).to eq 1
      expect(result[:max]).to eq 5
      expect(result[:median]).to eq 3
      expect(result[:mean]).to eq 3.0
      expect(result[:q1]).to eq 2
      expect(result[:q3]).to eq 4
      expect(result[:standard_deviation]).to be_within(1e-10).of(Math.sqrt(2))
    end

    it 'handles floats and preserves precision' do
      samples = [30.0, 10.0, 20.0]
      result = described_class.call(samples)

      expect(result[:min]).to eq 10.0
      expect(result[:max]).to eq 30.0
      expect(result[:median]).to eq 20.0
      expect(result[:mean]).to eq 20.0
      expect(result[:q1]).to eq 10.0
      expect(result[:q3]).to eq 30.0
      expect(result[:standard_deviation]).to be_within(1e-10).of(Math.sqrt(200.0/3.0))
    end
  end
end

