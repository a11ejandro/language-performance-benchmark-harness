require 'rails_helper'

RSpec.describe RubyWorker, type: :worker do
  subject(:worker) { described_class.new }

  # Create six ordered samples: values 10, 20, 30, 40, 50, 60
  before do
    [10.0, 20.0, 30.0, 40.0, 50.0, 60.0].each { |v| Sample.create!(value: v) }
  end

  let!(:task)    { Task.create!(name: 'T', page: 2, per_page: 2, runs: 1) }
  let!(:handler) { Handler.create!(task:, handler_type: 'ruby') }
  let!(:test_run){ TestRun.create!(handler:, consequent_number: 1) }

  # For page 2, per_page 2 → offset 2, limit 2 → [30.0, 40.0]
  let(:window_values) { [30.0, 40.0] }
  let(:expected_stats) { CalculateStatistics.call(window_values) }

  before do
    # Deterministic timing and memory (keep real get_page_values behavior)
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(1.0, 1.123)
    allow(worker).to receive(:measure_peak_resident_memory) do |&blk|
      measurement = blk.call
      [measurement, 2048.0]
    end
  end

  describe '#perform' do
    it 'fetches values from Samples based on task.page and per_page' do
      expect { worker.perform(test_run.id) }.to change { TestResult.count }.by(1)
      # Validate that the selected window drove the stats
      tr = TestResult.last
      stats = tr.attributes.symbolize_keys.slice(:min, :max, :mean, :median, :q1, :q3, :standard_deviation)
      expect(stats).to eq(expected_stats)
    end

    it 'persists deterministic duration and memory from instrumentation' do
      worker.perform(test_run.id)
      tr = TestResult.last
      expect(tr.duration).to eq 0.123
      expect(tr.memory).to eq 2048.0
    end
  end
end
