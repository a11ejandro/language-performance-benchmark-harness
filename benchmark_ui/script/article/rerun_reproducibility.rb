#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../config/environment"
require "fileutils"
require "open3"
require "time"

ROOT = Rails.root.to_s
ARCHIVE_ROOT = File.join(ROOT, "tmp", "repro_runs")

def usage
  warn <<~USAGE
    Usage:
      ruby script/article/rerun_reproducibility.rb snapshot [name_or_dir]
      ruby script/article/rerun_reproducibility.rb compare BASELINE_DIR [CANDIDATE_DIR]

    snapshot:
      Copies the canonical outputs under docs/ into tmp/repro_runs/<name_or_timestamp>/.

    compare:
      Compares durations_selected.csv and memory_selected.csv against the numeric rerun policy.
      BASELINE_DIR and CANDIDATE_DIR may be absolute paths or paths relative to benchmark_ui/.
      If CANDIDATE_DIR is omitted, current docs/ outputs are used.
  USAGE
end

def repo_head
  stdout, status = Open3.capture2("git", "rev-parse", "HEAD", chdir: ROOT)
  status.success? ? stdout.strip : "unknown"
end

def resolve_dir(path)
  return nil if path.nil? || path.strip.empty?
  return path if File.absolute_path(path) == path

  File.expand_path(path, ROOT)
end

def canonical_source_map(base_dir = ROOT)
  RerunReproducibility::Comparison::CANONICAL_FILES.transform_values { |segments| File.join(base_dir, *segments) }
end

def ensure_files_exist!(paths)
  missing = paths.values.reject { |path| File.exist?(path) }
  return if missing.empty?

  warn "Missing canonical files:"
  missing.each { |path| warn "  #{path}" }
  exit 1
end

def snapshot_destination(arg)
  return resolve_dir(arg) unless arg.nil? || arg.strip.empty?

  File.join(ARCHIVE_ROOT, Time.now.utc.strftime("%Y%m%dT%H%M%SZ"))
end

def write_manifest!(dest_dir)
  manifest_path = File.join(dest_dir, "manifest.txt")
  File.write(manifest_path, <<~TEXT)
    created_at_utc=#{Time.now.utc.iso8601}
    git_head=#{repo_head}
    root=#{ROOT}
  TEXT
end

def snapshot!(dest_dir)
  source_paths = canonical_source_map
  ensure_files_exist!(source_paths)

  FileUtils.mkdir_p(File.join(dest_dir, "data"))
  FileUtils.mkdir_p(File.join(dest_dir, "figures"))

  source_paths.each do |filename, source_path|
    group = filename.end_with?(".csv", ".md") ? "data" : "figures"
    dest_path = File.join(dest_dir, group, filename)
    FileUtils.cp(source_path, dest_path)
    puts "copied #{source_path} -> #{dest_path}"
  end

  write_manifest!(dest_dir)
  puts "snapshot saved to #{dest_dir}"
end

def compare!(baseline_dir, candidate_dir)
  baseline_root = resolve_dir(baseline_dir)
  candidate_root = candidate_dir ? resolve_dir(candidate_dir) : ROOT
  candidate_root = ROOT if candidate_root.nil?

  comparison_run = RerunReproducibility::RecordComparison.call(
    baseline_label: File.basename(baseline_root),
    baseline_path: baseline_root,
    candidate_label: File.basename(candidate_root),
    candidate_path: candidate_root,
    baseline_ref: nil,
    candidate_ref: repo_head,
    environment_metadata: { "invoked_at_utc" => Time.now.utc.iso8601 }
  )

  if comparison_run.passed?
    puts "PASS rerun reproducibility policy"
    puts "baseline=#{baseline_root}"
    puts "candidate=#{candidate_root}"
    puts "comparison_run_id=#{comparison_run.id}"
    exit 0
  end

  warn "FAIL rerun reproducibility policy"
  warn "baseline=#{baseline_root}"
  warn "candidate=#{candidate_root}"
  warn "comparison_run_id=#{comparison_run.id}"
  comparison_run.comparison_statistics.where(passed: false).find_each do |row|
    warn "- #{row.metric} #{row.handler_type} per_page=#{row.per_page}: #{row.failure_reason}"
  end
  exit 1
end

command = ARGV.shift

case command
when "snapshot"
  snapshot!(snapshot_destination(ARGV.shift))
when "compare"
  baseline = ARGV.shift
  candidate = ARGV.shift
  if baseline.nil? || baseline.strip.empty?
    usage
    exit 1
  end

  compare!(baseline, candidate)
else
  usage
  exit 1
end