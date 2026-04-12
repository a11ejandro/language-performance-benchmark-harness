require 'rails_helper'
require 'csv'

RSpec.describe SelectedTasksMemoryCsvExporter do
  def create_handler(task, handler_type, memories: [])
    handler = Handler.create!(task: task, handler_type: handler_type)
    if memories.any?
      run = TestRun.create!(handler: handler)
      memories.each do |m|
        TestResult.create!(test_run: run, memory: m)
      end
    end
    handler
  end

  it 'exports long-format memory rows for selected tasks with 6 decimal precision' do
    t1 = Task.create!(name: 'A')
    t2 = Task.create!(name: 'B')
    create_handler(t1, 'go', memories: [1, 2.5])
    create_handler(t2, 'ruby', memories: [3])

    csv = described_class.new(tasks: Task.where(id: [t1.id, t2.id])).generate
    rows = CSV.parse(csv)
    expect(rows.first).to eq(%w[task handler_type index memory])
    expect(rows).to include(['A', 'go', '0', '1.000000'])
    expect(rows).to include(['A', 'go', '1', '2.500000'])
    expect(rows).to include(['B', 'ruby', '0', '3.000000'])
  end

  it 'outputs header only when no memory samples exist' do
    t = Task.create!(name: 'Empty')
    create_handler(t, 'python', memories: [])
    csv = described_class.new(tasks: Task.where(id: t.id)).generate
    rows = CSV.parse(csv)
    expect(rows).to eq([%w[task handler_type index memory]])
  end
end
