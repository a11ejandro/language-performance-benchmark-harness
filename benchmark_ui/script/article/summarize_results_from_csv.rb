#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "time"

ROOT = File.expand_path("../..", __dir__)
DATA_DIR = File.join(ROOT, "docs", "data")

DURATIONS_PATH = File.join(DATA_DIR, "durations_selected.csv")
MEMORY_PATH = File.join(DATA_DIR, "memory_selected.csv")
OUT_PATH = File.join(DATA_DIR, "results_summary.md")

PREFERRED_HANDLERS = %w[ruby go python node].freeze

def task_to_int(task_value)
  return 0 if task_value.nil?
  s = task_value.to_s.strip
  return s.to_i if s.match?(/\A\d+\z/)
  m = s.match(/(\d+)/)
  m ? m[1].to_i : 0
end

def quantile(sorted, p)
  return sorted.first.to_f if sorted.length == 1

  idx = p * (sorted.length - 1)
  lo = idx.floor
  hi = idx.ceil
  return sorted[lo].to_f if lo == hi

  frac = idx - lo
  sorted[lo].to_f * (1.0 - frac) + sorted[hi].to_f * frac
end

def format_duration(v)
  format("%.6f", v)
end

def format_memory(v)
  # Keep bytes but shorten huge values.
  return format("%.2e", v) if v.abs >= 10_000_000
  v.round.to_i.to_s
end

def ordered_handlers(handlers)
  preferred = PREFERRED_HANDLERS.select { |h| handlers.include?(h) }
  preferred + (handlers - preferred).sort
end

def load_series(path, value_col)
  by_task_by_handler = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }

  CSV.foreach(path, headers: true) do |row|
    task = task_to_int(row["task"])
    handler = row["handler_type"].to_s
    value = Float(row[value_col]) rescue nil
    next if handler.empty? || value.nil?

    by_task_by_handler[task][handler] << value
  end

  tasks = by_task_by_handler.keys.sort
  handlers = ordered_handlers(by_task_by_handler.values.flat_map(&:keys).uniq)

  [tasks, handlers, by_task_by_handler]
end

def stats(values)
  v = values.compact.sort
  return nil if v.empty?

  {
    n: v.length,
    q1: quantile(v, 0.25),
    median: quantile(v, 0.50),
    q3: quantile(v, 0.75)
  }
end

def write_table(io, tasks:, handlers:, by_task_by_handler:, metric:, formatter:)
  io << "| per_page | "
  handlers.each { |h| io << "#{h} (median [q1,q3]) | " }
  io << "\n"

  io << "|---:|"
  handlers.each { io << "---:|" }
  io << "\n"

  tasks.each do |t|
    io << "| #{t} | "
    handlers.each do |h|
      s = stats(by_task_by_handler.dig(t, h) || [])
      if s.nil?
        io << "— | "
        next
      end
      med = formatter.call(s[:median])
      q1 = formatter.call(s[:q1])
      q3 = formatter.call(s[:q3])
      io << "#{med} [#{q1}, #{q3}] | "
    end
    io << "\n"
  end
end

unless File.exist?(DURATIONS_PATH) && File.exist?(MEMORY_PATH)
  warn "Missing CSVs. Expected:\n  #{DURATIONS_PATH}\n  #{MEMORY_PATH}\n\nGenerate them via:\n  bundle exec rails article:export_selected_csv"
  exit 1
end

d_tasks, d_handlers, d_series = load_series(DURATIONS_PATH, "duration")
m_tasks, m_handlers, m_series = load_series(MEMORY_PATH, "memory")

File.open(OUT_PATH, "w") do |f|
  f << "# Results summary (derived from selected CSV exports)\n\n"
  f << "Generated: #{Time.now.utc.iso8601}\n\n"
  f << "Sources:\n"
  f << "- docs/data/durations_selected.csv (task, handler_type, index, duration)\n"
  f << "- docs/data/memory_selected.csv (task, handler_type, index, memory)\n\n"

  f << "## Durations (seconds)\n\n"
  write_table(f,
              tasks: d_tasks,
              handlers: d_handlers,
              by_task_by_handler: d_series,
              metric: "duration",
              formatter: method(:format_duration))

  f << "\n## Memory (bytes)\n\n"
  write_table(f,
              tasks: m_tasks,
              handlers: m_handlers,
              by_task_by_handler: m_series,
              metric: "memory",
              formatter: method(:format_memory))
end

puts "Wrote #{OUT_PATH}"
