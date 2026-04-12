# frozen_string_literal: true

require "rails_helper"
require "rake"

require Rails.root.join("lib", "article", "tooling", "configuration").to_s
require Rails.root.join("lib", "article", "tooling", "pipeline").to_s
require Rails.root.join("lib", "article", "tooling", "seed_samples").to_s
require Rails.root.join("lib", "article", "tooling", "replace_tasks").to_s
require Rails.root.join("lib", "article", "tooling", "benchmark_runner").to_s

RSpec.describe Article::Tooling::Pipeline do
  before do
    allow(Article::Tooling::SeedSamples).to receive(:call)
    allow(Article::Tooling::ReplaceTasks).to receive(:call)

    runner = instance_double(Article::Tooling::BenchmarkRunner, execute!: nil)
    allow(Article::Tooling::BenchmarkRunner).to receive(:new).and_return(runner)
  end

  it "returns :skipped when not waiting and not inline ruby-only" do
    config = Article::Tooling::Configuration.new(
      { mode: "enqueue", handlers: "ruby", schedule: "serial_by_handler", wait: "false" },
      {}
    )

    expect(Rake::Task).not_to receive(:[]).with("article:export_selected_csv")
    expect(Rake::Task).not_to receive(:[]).with("article:generate_results_summary")
    expect(Rake::Task).not_to receive(:[]).with("article:generate_figures")

    expect(described_class.call(config)).to eq(:skipped)
  end

  it "returns :exported when wait=true" do
    config = Article::Tooling::Configuration.new(
      { mode: "enqueue", handlers: "ruby", schedule: "serial_by_handler", wait: "true" },
      {}
    )

    export_task = instance_double(Rake::Task, reenable: nil, invoke: nil)
    summary_task = instance_double(Rake::Task, reenable: nil, invoke: nil)
    figures_task = instance_double(Rake::Task, reenable: nil, invoke: nil)

    expect(Rake::Task).to receive(:[]).with("article:export_selected_csv").twice.and_return(export_task)
    expect(Rake::Task).to receive(:[]).with("article:generate_results_summary").twice.and_return(summary_task)
    expect(Rake::Task).to receive(:[]).with("article:generate_figures").twice.and_return(figures_task)
    expect(export_task).to receive(:reenable)
    expect(export_task).to receive(:invoke)
    expect(summary_task).to receive(:reenable)
    expect(summary_task).to receive(:invoke)
    expect(figures_task).to receive(:reenable)
    expect(figures_task).to receive(:invoke)

    expect(described_class.call(config)).to eq(:exported)
  end

  it "returns :exported when inline ruby-only" do
    config = Article::Tooling::Configuration.new(
      { mode: "inline", handlers: "ruby", schedule: "serial_by_handler", wait: "false" },
      {}
    )

    export_task = instance_double(Rake::Task, reenable: nil, invoke: nil)
    summary_task = instance_double(Rake::Task, reenable: nil, invoke: nil)
    figures_task = instance_double(Rake::Task, reenable: nil, invoke: nil)

    expect(Rake::Task).to receive(:[]).with("article:export_selected_csv").twice.and_return(export_task)
    expect(Rake::Task).to receive(:[]).with("article:generate_results_summary").twice.and_return(summary_task)
    expect(Rake::Task).to receive(:[]).with("article:generate_figures").twice.and_return(figures_task)
    expect(export_task).to receive(:reenable)
    expect(export_task).to receive(:invoke)
    expect(summary_task).to receive(:reenable)
    expect(summary_task).to receive(:invoke)
    expect(figures_task).to receive(:reenable)
    expect(figures_task).to receive(:invoke)

    expect(described_class.call(config)).to eq(:exported)
  end
end
