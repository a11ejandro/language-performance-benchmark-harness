module RerunReproducibility
  class RecordComparison
    def self.call(baseline_label:, baseline_path:, candidate_label:, candidate_path:, baseline_ref: nil, candidate_ref: nil, environment_metadata: {})
      comparison = Comparison.call(baseline_root: baseline_path, candidate_root: candidate_path)

      comparison_run = ComparisonRun.create!(
        baseline_label:,
        baseline_path: File.expand_path(baseline_path),
        candidate_label:,
        candidate_path: File.expand_path(candidate_path),
        baseline_ref:,
        candidate_ref:,
        status: comparison.passed ? "completed" : "failed",
        passed: comparison.passed,
        failure_count: comparison.failures.size,
        environment_metadata: environment_metadata,
        notes: comparison.failures.join("\n"),
        started_at: Time.current,
        finished_at: Time.current
      )

      comparison.statistics.each do |row|
        comparison_run.comparison_statistics.create!(row)
      end

      comparison_run
    end
  end
end