# frozen_string_literal: true

namespace :article do
  desc "Seed deterministic samples via db:seed. Args: rows (default 100000), seed (default 123), dist (uniform|normal|survey)"
  task :seed_samples, [:rows, :seed, :dist] => :environment do |_t, args|
    config = Article::Tooling::Configuration.new(args)
    Article::Tooling::SeedSamples.call(rows: config.rows, seed: config.seed, dist: config.dist)
  end

  desc "Create (or replace) standard tasks. Args: per_pages (comma list), runs (default 30), page (default 1)"
  task :setup_tasks, [:per_pages, :runs, :page] => :environment do |_t, args|
    config = Article::Tooling::Configuration.new(args)
    Article::Tooling::ReplaceTasks.call(per_pages: config.per_page_integers, runs: config.runs, page: config.page)
  end

  desc "Export selected-tasks long CSVs into docs/data/."
  task export_selected_csv: :environment do
    out_dir = Rails.root.join("docs", "data")
    FileUtils.mkdir_p(out_dir)

    tasks = Task.where(selected: true)

    durations_csv = SelectedTasksDurationCsvExporter.new(tasks: tasks).generate
    memory_csv = SelectedTasksMemoryCsvExporter.new(tasks: tasks).generate

    durations_path = out_dir.join("durations_selected.csv")
    memory_path = out_dir.join("memory_selected.csv")

    durations_path.write(durations_csv)
    memory_path.write(memory_csv)

    puts "[article:export_selected_csv] wrote #{durations_path}"
    puts "[article:export_selected_csv] wrote #{memory_path}"
  end

  desc "Generate docs/data/results_summary.md from the selected long-format CSV exports"
  task generate_results_summary: :environment do
    require "rbconfig"

    script = Rails.root.join("script", "article", "summarize_results_from_csv.rb")
    unless script.exist?
      raise "Missing script: #{script}"
    end

    ok = system(RbConfig.ruby.to_s, script.to_s)
    raise "Failed to generate results summary" unless ok
  end

  desc "Generate static SVG figures for the article from docs/data/*.csv"
  # Usage:
  #   bundle exec rails "article:generate_figures[/path/to/durations.csv,/path/to/memory.csv,/path/to/out_dir]"
  # or via env vars:
  #   DURATIONS_PATH=... MEMORY_PATH=... FIGURES_OUT_DIR=... bundle exec rails article:generate_figures
  task :generate_figures, %i[durations memory out] => :environment do |_t, args|
    require Rails.root.join("lib", "article", "figure_generator")

    default_durations = Rails.root.join("docs", "data", "durations_selected.csv")
    default_memory = Rails.root.join("docs", "data", "memory_selected.csv")
    default_out = Rails.root.join("docs", "figures")

    durations_path = Pathname.new((args[:durations] || ENV["DURATIONS_PATH"] || default_durations).to_s)
    memory_path = Pathname.new((args[:memory] || ENV["MEMORY_PATH"] || default_memory).to_s)
    out_dir = Pathname.new((args[:out] || ENV["FIGURES_OUT_DIR"] || default_out).to_s)

    FileUtils.mkdir_p(out_dir)

    puts "[article:generate_figures] durations: #{durations_path}"
    puts "[article:generate_figures] memory:    #{memory_path}"
    puts "[article:generate_figures] out:       #{out_dir}"

    Article::FigureGenerator.generate!(
      durations_path: durations_path.to_s,
      memory_path: memory_path.to_s,
      out_dir: out_dir.to_s
    )
  end


  desc "One-command pipeline: seed samples, create tasks, enqueue or run inline, and (when possible) export CSV. Configure via env vars."
  task generate_all: :environment do
    config = Article::Tooling::Configuration.new
    status = Article::Tooling::Pipeline.call(config)

    if status == :skipped
      puts "[article:generate_all] run article:export_selected_csv after workers finish"
    end
  end
end

