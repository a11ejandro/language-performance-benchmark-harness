require 'rails_helper'

RSpec.describe RerunReproducibility::RecordComparison do
  def write_series(root, filename, header, rows)
    dir = File.join(root, "docs", "data")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, filename), ([header] + rows).join("\n") + "\n")
  end

  def write_figures(root)
    dir = File.join(root, "docs", "figures")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "figure_duration_boxplots.svg"), "<svg></svg>\n")
    File.write(File.join(dir, "figure_memory_boxplots.svg"), "<svg></svg>\n")
  end

  def write_summary(root)
    dir = File.join(root, "docs", "data")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "results_summary.md"), "# Summary\n")
  end

  def build_root_with_passing_data
    root = Dir.mktmpdir("record-comparison")
    write_series(root, "durations_selected.csv", "task,handler_type,index,duration",
                 ["100,go,0,1.0", "100,go,1,1.1"])
    write_series(root, "memory_selected.csv", "task,handler_type,index,memory",
                 ["100,go,0,100.0", "100,go,1,101.0"])
    write_summary(root)
    write_figures(root)
    root
  end

  it "persists a ComparisonRun and its statistics" do
    baseline = build_root_with_passing_data
    candidate = build_root_with_passing_data

    expect do
      described_class.call(
        baseline_label: 'v1.0-paper',
        baseline_path: baseline,
        candidate_label: 'HEAD',
        candidate_path: candidate
      )
    end.to change(ComparisonRun, :count).by(1).and change(ComparisonStatistic, :count).by(2)

    run = ComparisonRun.last
    expect(run.baseline_label).to eq('v1.0-paper')
    expect(run.candidate_label).to eq('HEAD')
    expect(run.status).to eq('completed')
    expect(run.passed).to be(true)
    expect(run.failure_count).to eq(0)
    expect(run.comparison_statistics.count).to eq(2)
  ensure
    FileUtils.remove_entry(baseline) if baseline && Dir.exist?(baseline)
    FileUtils.remove_entry(candidate) if candidate && Dir.exist?(candidate)
  end

  it "records a failed ComparisonRun when policy is violated" do
    baseline = build_root_with_passing_data
    candidate = Dir.mktmpdir("record-comparison-fail")
    write_series(candidate, "durations_selected.csv", "task,handler_type,index,duration",
                 ["100,go,0,5.0", "100,go,1,5.0"])
    write_series(candidate, "memory_selected.csv", "task,handler_type,index,memory",
                 ["100,go,0,100.0", "100,go,1,101.0"])
    write_summary(candidate)
    write_figures(candidate)

    run = described_class.call(
      baseline_label: 'v1.0-paper',
      baseline_path: baseline,
      candidate_label: 'bad-run',
      candidate_path: candidate
    )

    expect(run.passed).to be(false)
    expect(run.status).to eq('failed')
    expect(run.failure_count).to be > 0
    expect(run.comparison_statistics.where(passed: false).count).to be > 0
  ensure
    FileUtils.remove_entry(baseline) if baseline && Dir.exist?(baseline)
    FileUtils.remove_entry(candidate) if candidate && Dir.exist?(candidate)
  end
end
