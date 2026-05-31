require "csv"

module RerunReproducibility
  class Comparison
    ORDER_CHECK_WORKLOADS = [1000, 10_000, 100_000].freeze
    DURATION_MIN_PER_PAGE = 100
    DURATION_RATIO_RANGE = (0.5..2.0)
    MEMORY_RATIO_RANGE = (0.8..1.25)
    ORDER_OF_MAGNITUDE_LIMIT = 10.0
    PREFERRED_HANDLERS = %w[go ruby python node].freeze

    CANONICAL_FILES = {
      "durations_selected.csv" => %w[docs data durations_selected.csv],
      "memory_selected.csv" => %w[docs data memory_selected.csv],
      "results_summary.md" => %w[docs data results_summary.md],
      "figure_duration_boxplots.svg" => %w[docs figures figure_duration_boxplots.svg],
      "figure_memory_boxplots.svg" => %w[docs figures figure_memory_boxplots.svg]
    }.freeze

    Result = Struct.new(:baseline_root, :candidate_root, :passed, :failures, :statistics, keyword_init: true)

    def self.call(baseline_root:, candidate_root:)
      new(baseline_root:, candidate_root:).call
    end

    def initialize(baseline_root:, candidate_root:)
      @baseline_root = File.expand_path(baseline_root)
      @candidate_root = File.expand_path(candidate_root)
    end

    def call
      ensure_files_exist!(baseline_paths)
      ensure_files_exist!(candidate_paths)

      baseline_durations = load_metric(baseline_paths.fetch("durations_selected.csv"), "duration")
      candidate_durations = load_metric(candidate_paths.fetch("durations_selected.csv"), "duration")
      baseline_memory = load_metric(baseline_paths.fetch("memory_selected.csv"), "memory")
      candidate_memory = load_metric(candidate_paths.fetch("memory_selected.csv"), "memory")

      statistics = build_statistics(baseline_durations:, candidate_durations:, baseline_memory:, candidate_memory:)
      failures = collect_failures(statistics)

      Result.new(
        baseline_root:,
        candidate_root:,
        passed: failures.empty?,
        failures:,
        statistics:
      )
    end

    private

    attr_reader :baseline_root, :candidate_root

    def baseline_paths
      @baseline_paths ||= canonical_paths_for(baseline_root)
    end

    def candidate_paths
      @candidate_paths ||= canonical_paths_for(candidate_root)
    end

    def canonical_paths_for(root)
      if File.directory?(File.join(root, "docs", "data")) || File.directory?(File.join(root, "docs", "figures"))
        CANONICAL_FILES.transform_values { |segments| File.join(root, *segments) }
      else
        CANONICAL_FILES.transform_values do |segments|
          relative_segments = segments[1..]
          File.join(root, *relative_segments)
        end
      end
    end

    def ensure_files_exist!(paths)
      missing = paths.values.reject { |path| File.exist?(path) }
      return if missing.empty?

      raise ArgumentError, "Missing canonical files:\n  #{missing.join("\n  ")}" 
    end

    def load_metric(path, value_column)
      series = Hash.new { |h, workload| h[workload] = Hash.new { |hh, handler| hh[handler] = [] } }

      CSV.foreach(path, headers: true) do |row|
        workload = Integer(row["task"], 10) rescue nil
        handler = row["handler_type"].to_s
        value = Float(row[value_column]) rescue nil
        next if workload.nil? || handler.empty? || value.nil?

        series[workload][handler] << value
      end

      series.transform_values do |handlers|
        handlers.transform_values { |values| series_stats(values) }
      end
    end

    def series_stats(values)
      sorted = values.sort
      {
        q1: quantile(sorted, 0.25),
        median: quantile(sorted, 0.5),
        q3: quantile(sorted, 0.75)
      }
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

    def build_statistics(baseline_durations:, candidate_durations:, baseline_memory:, candidate_memory:)
      rows = []

      merged_keys(baseline_durations, candidate_durations).each do |workload, handler|
        rows << build_row(
          metric: "duration",
          workload:,
          handler:,
          baseline: baseline_durations.dig(workload, handler),
          candidate: candidate_durations.dig(workload, handler)
        )
      end

      merged_keys(baseline_memory, candidate_memory).each do |workload, handler|
        rows << build_row(
          metric: "memory",
          workload:,
          handler:,
          baseline: baseline_memory.dig(workload, handler),
          candidate: candidate_memory.dig(workload, handler)
        )
      end

      attach_ordering_failures!(rows, baseline_durations, candidate_durations)
      rows
    end

    def merged_keys(baseline_stats, candidate_stats)
      workloads = (baseline_stats.keys + candidate_stats.keys).uniq.sort
      workloads.flat_map do |workload|
        handlers = ((baseline_stats[workload] || {}).keys + (candidate_stats[workload] || {}).keys).uniq.sort
        handlers.map { |handler| [workload, handler] }
      end
    end

    def build_row(metric:, workload:, handler:, baseline:, candidate:)
      failure_reason = nil
      passed = true

      if baseline.nil? || candidate.nil?
        passed = false
        failure_reason = "missing series"
      else
        value_ratio = ratio(candidate[:median], baseline[:median])
        if metric == "duration" && workload >= DURATION_MIN_PER_PAGE
          unless DURATION_RATIO_RANGE.cover?(value_ratio)
            passed = false
            failure_reason = format("median ratio %.3f outside [%.2f, %.2f]", value_ratio, DURATION_RATIO_RANGE.begin, DURATION_RATIO_RANGE.end)
          end
        elsif metric == "memory" && workload >= DURATION_MIN_PER_PAGE
          unless MEMORY_RATIO_RANGE.cover?(value_ratio)
            passed = false
            failure_reason = format("median ratio %.3f outside [%.2f, %.2f]", value_ratio, MEMORY_RATIO_RANGE.begin, MEMORY_RATIO_RANGE.end)
          end
        end

        if value_ratio >= ORDER_OF_MAGNITUDE_LIMIT
          passed = false
          failure_reason = [failure_reason, format("median ratio %.3f exceeds order-of-magnitude limit", value_ratio)].compact.join("; ")
        end
      end

      {
        metric:,
        handler_type: handler,
        per_page: workload,
        baseline_q1: baseline&.dig(:q1),
        baseline_median: baseline&.dig(:median),
        baseline_q3: baseline&.dig(:q3),
        candidate_q1: candidate&.dig(:q1),
        candidate_median: candidate&.dig(:median),
        candidate_q3: candidate&.dig(:q3),
        ratio: baseline && candidate ? ratio(candidate[:median], baseline[:median]) : nil,
        passed:,
        failure_reason:
      }
    end

    def ratio(candidate, baseline)
      return Float::INFINITY if baseline.zero? && !candidate.zero?
      return 1.0 if baseline.zero? && candidate.zero?

      candidate / baseline
    end

    def attach_ordering_failures!(rows, baseline_durations, candidate_durations)
      ORDER_CHECK_WORKLOADS.each do |workload|
        baseline_handlers = baseline_durations[workload]
        candidate_handlers = candidate_durations[workload]
        next if baseline_handlers.nil? || candidate_handlers.nil?

        baseline_order = ordered_handlers_for(baseline_handlers).sort_by { |handler| baseline_handlers.fetch(handler).fetch(:median) }
        candidate_order = ordered_handlers_for(candidate_handlers).sort_by { |handler| candidate_handlers.fetch(handler).fetch(:median) }
        next if baseline_order == candidate_order

        rows.select { |row| row[:metric] == "duration" && row[:per_page] == workload }.each do |row|
          row[:passed] = false
          ordering_reason = "ordering mismatch baseline=#{baseline_order.join('>')} candidate=#{candidate_order.join('>')}"
          row[:failure_reason] = [row[:failure_reason], ordering_reason].compact.join("; ")
        end
      end
    end

    def ordered_handlers_for(workload_stats)
      present = workload_stats.keys
      preferred = PREFERRED_HANDLERS.select { |handler| present.include?(handler) }
      preferred + (present - preferred).sort
    end

    def collect_failures(statistics)
      statistics.filter_map do |row|
        next if row[:passed]

        "#{row[:metric]} #{row[:handler_type]} per_page=#{row[:per_page]}: #{row[:failure_reason]}"
      end
    end
  end
end