require 'rails_helper'
require 'csv'

RSpec.describe TaskSeriesCsvExporter do
  # Helper to build a handler with optional test_results for a single test_run
  def create_handler(task, handler_type, durations: [], memories: [])
    handler = Handler.create!(task: task, handler_type: handler_type)
    if durations.any? || memories.any?
      run = TestRun.create!(handler: handler)
      max = [durations.length, memories.length].max
      max.times do |i|
        TestResult.create!(
          test_run: run,
          duration: durations[i],
          memory: memories[i]
        )
      end
    end
    handler
  end

  describe '#generate' do
    let(:task) { Task.create! }

    it 'orders handler columns alphabetically by handler_type' do
      # Create in non-alphabetic order to verify deterministic ordering
      create_handler(task, 'ruby', durations: [1])
      create_handler(task, 'go', durations: [2, 3])
      create_handler(task, 'python', durations: [4, 5, 6])

      csv = described_class.new(task: task, metric: 'duration').generate
      rows = CSV.parse(csv)
      expect(rows.first).to eq(['index', 'go', 'python', 'ruby'])
    end

  it 'pads unequal series with blanks and shows 6 decimal places for integers' do
      create_handler(task, 'go', durations: [10, 20, 30])
      create_handler(task, 'ruby', durations: [5])

      csv = described_class.new(task: task, metric: 'duration').generate
      rows = CSV.parse(csv)
      # Header + 3 data rows (length of longest series)
      expect(rows.length).to eq 4
      # Row 0
  expect(rows[1]).to eq(['0', '10.000000', '5.000000'])
      # Row 1 (ruby missing)
  expect(rows[2]).to eq(['1', '20.000000', nil])
      # Row 2 (ruby missing)
  expect(rows[3]).to eq(['2', '30.000000', nil])
    end

    it 'returns only header row when all handlers have empty series' do
      create_handler(task, 'go')
      create_handler(task, 'ruby')

      csv = described_class.new(task: task, metric: 'duration').generate
      rows = CSV.parse(csv)
      expect(rows).to eq([['index', 'go', 'ruby']])
    end

  it 'exports memory values when metric is memory with 6 decimal places' do
      create_handler(task, 'go', memories: [1.5, 2.5])
      create_handler(task, 'ruby', memories: [9.9])

      csv = described_class.new(task: task, metric: 'memory').generate
      rows = CSV.parse(csv)
      expect(rows.first).to eq(['index', 'go', 'ruby'])
  expect(rows[1]).to eq(['0', '1.500000', '9.900000'])
  expect(rows[2]).to eq(['1', '2.500000', nil])
    end

  it 'always shows 6 decimal places for integer-like values across handlers' do
      create_handler(task, 'go', durations: [1, 2])
      create_handler(task, 'ruby', durations: [3])
      csv = described_class.new(task: task, metric: 'duration').generate
      rows = CSV.parse(csv)
  expect(rows[1]).to eq(['0', '1.000000', '3.000000'])
  expect(rows[2]).to eq(['1', '2.000000', nil])
    end

    it 'raises for unsupported metric' do
      expect do
        described_class.new(task: task, metric: 'bogus').generate
      end.to raise_error(ArgumentError, /Unsupported metric/)
    end
  end
end
