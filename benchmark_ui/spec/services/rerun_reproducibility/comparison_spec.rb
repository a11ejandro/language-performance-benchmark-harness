require "rails_helper"

RSpec.describe RerunReproducibility::Comparison do
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

  def build_root
    Dir.mktmpdir("rerun-comparison")
  end

  it "passes when medians stay within the documented bands" do
    baseline = build_root
    candidate = build_root

    header_duration = "task,handler_type,index,duration"
    header_memory = "task,handler_type,index,memory"

    duration_rows = [
      "100,go,0,1.0",
      "100,go,1,1.2",
      "100,ruby,0,2.0",
      "100,ruby,1,2.2",
      "1000,go,0,4.0",
      "1000,go,1,4.2",
      "1000,ruby,0,8.0",
      "1000,ruby,1,8.2"
    ]
    candidate_duration_rows = [
      "100,go,0,1.1",
      "100,go,1,1.3",
      "100,ruby,0,2.1",
      "100,ruby,1,2.4",
      "1000,go,0,4.3",
      "1000,go,1,4.4",
      "1000,ruby,0,8.1",
      "1000,ruby,1,8.5"
    ]

    memory_rows = [
      "100,go,0,100.0",
      "100,go,1,102.0",
      "100,ruby,0,200.0",
      "100,ruby,1,202.0",
      "1000,go,0,150.0",
      "1000,go,1,151.0",
      "1000,ruby,0,300.0",
      "1000,ruby,1,302.0"
    ]
    candidate_memory_rows = [
      "100,go,0,101.0",
      "100,go,1,103.0",
      "100,ruby,0,205.0",
      "100,ruby,1,206.0",
      "1000,go,0,151.0",
      "1000,go,1,152.0",
      "1000,ruby,0,303.0",
      "1000,ruby,1,305.0"
    ]

    write_series(baseline, "durations_selected.csv", header_duration, duration_rows)
    write_series(candidate, "durations_selected.csv", header_duration, candidate_duration_rows)
    write_series(baseline, "memory_selected.csv", header_memory, memory_rows)
    write_series(candidate, "memory_selected.csv", header_memory, candidate_memory_rows)
    write_summary(baseline)
    write_summary(candidate)
    write_figures(baseline)
    write_figures(candidate)

    result = described_class.call(baseline_root: baseline, candidate_root: candidate)

    expect(result.passed).to be(true)
    expect(result.failures).to be_empty
    expect(result.statistics).not_to be_empty
  ensure
    FileUtils.remove_entry(baseline) if baseline && Dir.exist?(baseline)
    FileUtils.remove_entry(candidate) if candidate && Dir.exist?(candidate)
  end

  it "fails when a duration median breaches the policy band" do
    baseline = build_root
    candidate = build_root

    write_series(baseline, "durations_selected.csv", "task,handler_type,index,duration", ["100,go,0,1.0", "100,go,1,1.0"])
    write_series(candidate, "durations_selected.csv", "task,handler_type,index,duration", ["100,go,0,4.0", "100,go,1,4.0"])
    write_series(baseline, "memory_selected.csv", "task,handler_type,index,memory", ["100,go,0,100.0", "100,go,1,100.0"])
    write_series(candidate, "memory_selected.csv", "task,handler_type,index,memory", ["100,go,0,100.0", "100,go,1,100.0"])
    write_summary(baseline)
    write_summary(candidate)
    write_figures(baseline)
    write_figures(candidate)

    result = described_class.call(baseline_root: baseline, candidate_root: candidate)

    expect(result.passed).to be(false)
    expect(result.failures.join("\n")).to include("outside [0.50, 2.00]")
  ensure
    FileUtils.remove_entry(baseline) if baseline && Dir.exist?(baseline)
    FileUtils.remove_entry(candidate) if candidate && Dir.exist?(candidate)
  end
end