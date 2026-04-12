# frozen_string_literal: true

require "csv"
require "fileutils"

# Summarize docs/data/*_selected.csv into markdown tables.
#
# Uses the same quantile definition as Article::FigureGenerator (linear interpolation).

ROOT = File.expand_path("../..", __dir__)
DATA_DIR = File.join(ROOT, "docs", "data")

DURATIONS_PATH = File.join(DATA_DIR, "durations_selected.csv")
MEMORY_PATH = File.join(DATA_DIR, "memory_selected.csv")
OUT_PATH = File.join(DATA_DIR, "results_summary.md")

def quantile(sorted, p)
  return sorted.first.to_f if sorted.length == 1

  idx = p * (sorted.length - 1)
  lo = idx.floor
  hi = idx.ceil
  return sorted[lo].to_f if lo == hi

  frac = idx - lo
  sorted[lo].to_f * (1.0 - frac) + sorted[hi].to_f * frac
end

def box_stats(values)
  sorted = values.sort
  q1 = quantile(sorted, 0.25)
  med = quantile(sorted, 0.5)
  q3 = quantile(sorted, 0.75)
  { q1: q1, median: med, q3: q3, iqr: (q3 - q1) }
end

def fmt_duration(v)
  return "–" if v.nil?
  if v.abs < 0.0001
    format("%.2e", v)
  elsif v.abs < 0.01
    format("%.6f", v)
  elsif v.abs < 1
    format("%.4f", v)
  else
    format("%.3f", v)
  end
end

def fmt_mib(v)
  return "–" if v.nil?
  mib = v.to_f / (1024.0 * 1024.0)
  format("%.2f", mib)
end

def load_long(path, metric)
  rows = []
  CSV.foreach(path, headers: true) do |r|
    task = Integer(r["task"]) rescue nil
    handler = r["handler_type"].to_s
    value = Float(r[metric]) rescue nil
    next if task.nil? || handler.empty? || value.nil?
    rows << [task, handler, value]
  end
  rows
end

def compute(rows)
  by = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }
  tasks = {}
  handlers = {}

  rows.each do |task, handler, value|
    tasks[task] = true
    handlers[handler] = true
    by[task][handler] << value
  end

  task_list = tasks.keys.sort
  handler_list = ["ruby", "go", "python", "node"].select { |h| handlers.key?(h) } + (handlers.keys - ["ruby", "go", "python", "node"]).sort

  stats = {}
  task_list.each do |task|
    stats[task] = {}
    handler_list.each do |handler|
      values = by[task][handler]
      next if values.empty?
      stats[task][handler] = box_stats(values)
    end
  end

  { tasks: task_list, handlers: handler_list, stats: stats }
end

def write_table(io, title:, dataset:, formatter:)
  io.puts "## #{title}"
  io.puts

  handlers = dataset.fetch(:handlers)
  io.puts (["per_page"] + handlers).join(" | ")
  io.puts (["---"] * (handlers.length + 1)).join(" | ")

  dataset.fetch(:tasks).each do |task|
    row = [task.to_s]
    handlers.each do |handler|
      s = dataset.dig(:stats, task, handler)
      if s
        cell = "#{formatter.call(s[:median])} (#{formatter.call(s[:q1])}–#{formatter.call(s[:q3])})"
      else
        cell = "–"
      end
      row << cell
    end
    io.puts row.join(" | ")
  end

  io.puts
end

FileUtils.mkdir_p(DATA_DIR)

unless File.exist?(DURATIONS_PATH)
  warn "missing #{DURATIONS_PATH}"
  exit 1
end

unless File.exist?(MEMORY_PATH)
  warn "missing #{MEMORY_PATH}"
  exit 1
end

durations_rows = load_long(DURATIONS_PATH, "duration")
memory_rows = load_long(MEMORY_PATH, "memory")

summary_durations = compute(durations_rows)
summary_memory = compute(memory_rows)

File.open(OUT_PATH, "w") do |io|
  io.puts "# Results summary (from selected CSV exports)"
  io.puts
  io.puts "Generated from:"
  io.puts "- docs/data/durations_selected.csv"
  io.puts "- docs/data/memory_selected.csv"
  io.puts
  io.puts "Each cell is: median (Q1–Q3), using linear-interpolation quantiles."
  io.puts

  write_table(io, title: "Duration (seconds)", dataset: summary_durations, formatter: method(:fmt_duration))
  write_table(io, title: "Memory (MiB)", dataset: summary_memory, formatter: method(:fmt_mib))
end

puts "wrote #{OUT_PATH}"
