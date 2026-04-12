require 'rails_helper'
require 'csv'

RSpec.describe SelectedTasksDurationCsvExporter do
  def create_handler(task, handler_type, durations: [])
    handler = Handler.create!(task: task, handler_type: handler_type)
    if durations.any?
      run = TestRun.create!(handler: handler)
      durations.each do |d|
        TestResult.create!(test_run: run, duration: d)
      end
    end
    handler
  end

  it 'exports long-format duration rows for selected tasks with 6 decimal precision' do
    t1 = Task.create!(name: 'A')
    t2 = Task.create!(name: 'B')
    create_handler(t1, 'go', durations: [1, 2.5])
    create_handler(t2, 'ruby', durations: [3])

    csv = described_class.new(tasks: Task.where(id: [t1.id, t2.id])).generate
    rows = CSV.parse(csv)
    expect(rows.first).to eq(%w[task handler_type index duration])
    expect(rows).to include(['A', 'go', '0', '1.000000'])
    expect(rows).to include(['A', 'go', '1', '2.500000'])
    expect(rows).to include(['B', 'ruby', '0', '3.000000'])
  end

  it 'outputs header only when no duration samples exist' do
    t = Task.create!(name: 'Empty')
    create_handler(t, 'python', durations: [])
    csv = described_class.new(tasks: Task.where(id: t.id)).generate
    rows = CSV.parse(csv)
    expect(rows).to eq([%w[task handler_type index duration]])
  end
end
