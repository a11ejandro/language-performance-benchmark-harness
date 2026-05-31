require 'rails_helper'

RSpec.describe 'ComparisonRuns', type: :request do
  def create_comparison_run(passed: true)
    run = ComparisonRun.create!(
      baseline_label: 'v1.0-paper',
      baseline_path: '/tmp/baseline',
      candidate_label: 'HEAD',
      candidate_path: '/tmp/candidate',
      status: 'completed',
      passed: passed,
      failure_count: passed ? 0 : 1
    )
    run.comparison_statistics.create!(
      metric: 'duration',
      handler_type: 'go',
      per_page: 100,
      baseline_median: 1.0,
      candidate_median: 1.1,
      ratio: 1.1,
      passed: true
    )
    run
  end

  describe 'GET /comparison_runs' do
    it 'returns 200 and lists comparison runs' do
      run = create_comparison_run
      get comparison_runs_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(run.baseline_label)
      expect(response.body).to include(run.candidate_label)
      expect(response.body).to include('PASS')
    end

    it 'shows a message when no runs exist' do
      get comparison_runs_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No comparison runs recorded yet')
    end
  end

  describe 'GET /comparison_runs/:id' do
    it 'returns 200 and renders the statistics table' do
      run = create_comparison_run
      get comparison_run_path(run)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(run.baseline_label)
      expect(response.body).to include(run.candidate_label)
      expect(response.body).to include('Duration')
      expect(response.body).to include('go')
    end

    it 'returns 404 for a missing run' do
      get comparison_run_path(0)
      expect(response).to have_http_status(:not_found)
    end
  end
end
