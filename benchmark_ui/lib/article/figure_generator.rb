# frozen_string_literal: true

require "csv"
require "fileutils"

module Article
  class FigureGenerator
    TAB10 = [
      "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
      "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"
    ].freeze

    PREFERRED_HANDLERS = ["ruby", "go", "python", "node"].freeze

    def self.generate!(durations_path:, memory_path:, out_dir:)
      out_dir = out_dir.to_s
      FileUtils.mkdir_p(out_dir)

      durations = load_long_csv(durations_path, metric: "duration")
      memory = load_long_csv(memory_path, metric: "memory")

      write_svg(
        dataset: durations,
        metric: "duration",
        title: "Duration by page size (raw runs)",
        ylabel: "Duration (seconds)",
        out_path: File.join(out_dir, "figure_duration_boxplots.svg")
      )

      write_svg(
        dataset: memory,
        metric: "memory",
        title: "Memory by page size (raw runs)",
        ylabel: "Memory (bytes)",
        out_path: File.join(out_dir, "figure_memory_boxplots.svg")
      )
    end

    def self.load_long_csv(path, metric:)
      rows = []
      CSV.foreach(path, headers: true) do |row|
        task = task_to_int(row["task"])
        handler = row["handler_type"].to_s
        value = Float(row[metric]) rescue nil
        next if value.nil?
        rows << { task: task, handler: handler, value: value }
      end

      handlers = ordered_handlers(rows.map { |r| r[:handler] }.uniq)
      tasks = rows.map { |r| r[:task] }.uniq.sort

      { rows: rows, tasks: tasks, handlers: handlers }
    end

    def self.ordered_handlers(handlers)
      preferred = PREFERRED_HANDLERS.select { |h| handlers.include?(h) }
      preferred + (handlers - preferred).sort
    end

    def self.task_to_int(task_value)
      return 0 if task_value.nil?
      s = task_value.to_s.strip
      return s.to_i if s.match?(/\A\d+\z/)
      m = s.match(/(\d+)/)
      m ? m[1].to_i : 0
    end

    def self.write_svg(dataset:, metric:, title:, ylabel:, out_path:)
      tasks = dataset.fetch(:tasks)
      handlers = dataset.fetch(:handlers)
      rows = dataset.fetch(:rows)

      raise "No tasks to plot" if tasks.empty?

      series_by = {}
      handlers.each { |h| series_by[h] = {} }

      rows.each do |r|
        series_by[r[:handler]][r[:task]] ||= []
        series_by[r[:handler]][r[:task]] << r[:value]
      end

      stats_by = {}
      all_whisker_values = []

      handlers.each do |handler|
        stats_by[handler] = {}
        tasks.each do |task|
          values = (series_by[handler][task] || []).compact
          next if values.empty?
          stats = boxplot_stats(values)
          stats_by[handler][task] = stats
          all_whisker_values << stats[:whisker_low]
          all_whisker_values << stats[:whisker_high]
        end
      end

      y_min = all_whisker_values.min
      y_max = all_whisker_values.max
      if y_min.nil? || y_max.nil?
        raise "No values to plot for #{metric}"
      end
      if (y_max - y_min).abs < 1e-18
        y_min -= 1
        y_max += 1
      end

      width = [800, tasks.length * 90 + 220].max
      height = 450

      margin_left = 70
      margin_right = 220
      margin_top = 50
      margin_bottom = 60

      plot_x0 = margin_left
      plot_y0 = margin_top
      plot_w = width - margin_left - margin_right
      plot_h = height - margin_top - margin_bottom

      group_step = plot_w.to_f / tasks.length
      group_width = group_step * 0.8
      box_width = group_width / [handlers.length, 1].max

      y_to_px = lambda do |v|
        plot_y0 + (y_max - v) * plot_h.to_f / (y_max - y_min)
      end

      svg = +""
      svg << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      svg << "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"#{width}\" height=\"#{height}\" viewBox=\"0 0 #{width} #{height}\">\n"
      svg << "  <rect x=\"0\" y=\"0\" width=\"#{width}\" height=\"#{height}\" fill=\"white\"/>\n"

      # Title
      svg << "  <text x=\"#{width / 2}\" y=\"24\" text-anchor=\"middle\" font-family=\"system-ui, -apple-system\" font-size=\"16\">#{escape_xml(title)}</text>\n"

      # Axes
      svg << "  <line x1=\"#{plot_x0}\" y1=\"#{plot_y0 + plot_h}\" x2=\"#{plot_x0 + plot_w}\" y2=\"#{plot_y0 + plot_h}\" stroke=\"#111\" stroke-width=\"1\"/>\n"
      svg << "  <line x1=\"#{plot_x0}\" y1=\"#{plot_y0}\" x2=\"#{plot_x0}\" y2=\"#{plot_y0 + plot_h}\" stroke=\"#111\" stroke-width=\"1\"/>\n"

      # Y ticks
      tick_count = 5
      tick_count.times do |i|
        t = i.to_f / (tick_count - 1)
        val = y_max - t * (y_max - y_min)
        y = y_to_px.call(val)
        svg << "  <line x1=\"#{plot_x0 - 4}\" y1=\"#{y}\" x2=\"#{plot_x0}\" y2=\"#{y}\" stroke=\"#111\" stroke-width=\"1\"/>\n"
        svg << "  <text x=\"#{plot_x0 - 8}\" y=\"#{y + 4}\" text-anchor=\"end\" font-family=\"system-ui, -apple-system\" font-size=\"11\">#{escape_xml(format_y(val, metric: metric))}</text>\n"
        svg << "  <line x1=\"#{plot_x0}\" y1=\"#{y}\" x2=\"#{plot_x0 + plot_w}\" y2=\"#{y}\" stroke=\"#eee\" stroke-width=\"1\"/>\n" unless i == 0 || i == tick_count - 1
      end

      # Axis labels
      svg << "  <text x=\"#{plot_x0 + plot_w / 2}\" y=\"#{height - 18}\" text-anchor=\"middle\" font-family=\"system-ui, -apple-system\" font-size=\"12\">per_page</text>\n"
      svg << "  <text x=\"18\" y=\"#{plot_y0 + plot_h / 2}\" text-anchor=\"middle\" font-family=\"system-ui, -apple-system\" font-size=\"12\" transform=\"rotate(-90 18 #{plot_y0 + plot_h / 2})\">#{escape_xml(ylabel)}</text>\n"

      # X ticks
      tasks.each_with_index do |task, g|
        center = plot_x0 + group_step * (g + 0.5)
        svg << "  <text x=\"#{center}\" y=\"#{plot_y0 + plot_h + 20}\" text-anchor=\"middle\" font-family=\"system-ui, -apple-system\" font-size=\"11\">#{escape_xml(task.to_s)}</text>\n"
      end

      # Boxes
      handlers.each_with_index do |handler, i|
        color = TAB10[i % TAB10.length]
        tasks.each_with_index do |task, g|
          stats = stats_by.dig(handler, task)
          next unless stats

          group_center = plot_x0 + group_step * (g + 0.5)
          x_left = group_center - group_width / 2 + i * box_width
          x_right = x_left + box_width * 0.9
          x_mid = (x_left + x_right) / 2

          y_q1 = y_to_px.call(stats[:q1])
          y_q3 = y_to_px.call(stats[:q3])
          y_med = y_to_px.call(stats[:median])
          y_wlo = y_to_px.call(stats[:whisker_low])
          y_whi = y_to_px.call(stats[:whisker_high])

          rect_y = [y_q3, y_q1].min
          rect_h = (y_q1 - y_q3).abs

          # Whisker line
          svg << "  <line x1=\"#{x_mid}\" y1=\"#{y_whi}\" x2=\"#{x_mid}\" y2=\"#{y_wlo}\" stroke=\"#{color}\" stroke-width=\"1\"/>\n"
          # Caps
          cap_w = (box_width * 0.35)
          svg << "  <line x1=\"#{x_mid - cap_w / 2}\" y1=\"#{y_whi}\" x2=\"#{x_mid + cap_w / 2}\" y2=\"#{y_whi}\" stroke=\"#{color}\" stroke-width=\"1\"/>\n"
          svg << "  <line x1=\"#{x_mid - cap_w / 2}\" y1=\"#{y_wlo}\" x2=\"#{x_mid + cap_w / 2}\" y2=\"#{y_wlo}\" stroke=\"#{color}\" stroke-width=\"1\"/>\n"
          # Box
          svg << "  <rect x=\"#{x_left}\" y=\"#{rect_y}\" width=\"#{x_right - x_left}\" height=\"#{rect_h}\" fill=\"#{color}\" fill-opacity=\"0.35\" stroke=\"#{color}\" stroke-width=\"1\"/>\n"
          # Median
          svg << "  <line x1=\"#{x_left}\" y1=\"#{y_med}\" x2=\"#{x_right}\" y2=\"#{y_med}\" stroke=\"#{color}\" stroke-width=\"2\"/>\n"
        end
      end

      # Legend
      legend_x = plot_x0 + plot_w + 18
      legend_y = plot_y0 + 12
      svg << "  <text x=\"#{legend_x}\" y=\"#{legend_y}\" font-family=\"system-ui, -apple-system\" font-size=\"12\" font-weight=\"600\">handlers</text>\n"
      handlers.each_with_index do |handler, i|
        y = legend_y + 18 + i * 18
        color = TAB10[i % TAB10.length]
        svg << "  <line x1=\"#{legend_x}\" y1=\"#{y - 4}\" x2=\"#{legend_x + 18}\" y2=\"#{y - 4}\" stroke=\"#{color}\" stroke-width=\"6\" stroke-linecap=\"round\" opacity=\"0.6\"/>\n"
        svg << "  <text x=\"#{legend_x + 26}\" y=\"#{y}\" font-family=\"system-ui, -apple-system\" font-size=\"12\">#{escape_xml(handler)}</text>\n"
      end

      svg << "</svg>\n"

      File.write(out_path, svg)
      puts "wrote #{out_path}"
    end

    def self.boxplot_stats(values)
      sorted = values.sort
      q1 = quantile(sorted, 0.25)
      median = quantile(sorted, 0.5)
      q3 = quantile(sorted, 0.75)
      iqr = q3 - q1

      low_fence = q1 - 1.5 * iqr
      high_fence = q3 + 1.5 * iqr

      whisker_low = sorted.find { |v| v >= low_fence } || sorted.first
      whisker_high = sorted.reverse.find { |v| v <= high_fence } || sorted.last

      {
        q1: q1,
        median: median,
        q3: q3,
        whisker_low: whisker_low,
        whisker_high: whisker_high
      }
    end

    # Linear interpolation quantile, compatible with small N.
    def self.quantile(sorted, p)
      return sorted.first.to_f if sorted.length == 1

      idx = p * (sorted.length - 1)
      lo = idx.floor
      hi = idx.ceil
      return sorted[lo].to_f if lo == hi

      frac = idx - lo
      sorted[lo].to_f * (1.0 - frac) + sorted[hi].to_f * frac
    end

    def self.format_y(v, metric:)
      if metric == "memory"
        # Keep bytes but shorten huge values.
        return format("%.2e", v) if v.abs >= 10_000_000
        return v.round.to_i.to_s
      end

      # duration
      if v.abs < 0.01
        format("%.4f", v)
      elsif v.abs < 1
        format("%.3f", v)
      else
        format("%.2f", v)
      end
    end

    def self.escape_xml(s)
      s.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
    end
  end
end
