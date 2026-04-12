require 'rails_helper'

RSpec.describe 'Tasks', type: :request do
  describe 'POST /tasks/:id/recalculate_statistics' do
    it 'recalculates statistics for completed handlers' do
      task = Task.create!(name: 'Benchmark', page: 'test', per_page: 10, runs: 1)
      handler = Handler.create!(task:, handler_type: 'ruby')
      test_run = TestRun.create!(handler:, consequent_number: 0)
      TestResult.create!(test_run:, duration: 1.5, memory: 256.0)

      expect do
        post recalculate_statistics_task_path(task)
      end.to change { Statistic.where(handler: handler).count }.from(0).to(2)

      expect(response).to redirect_to(task_path(task))

      duration_stats = handler.reload.duration_statistics
      memory_stats = handler.memory_statistics

      expect(duration_stats.mean).to eq(1.5)
      expect(memory_stats.mean).to eq(256.0)
    end
  end
end
