require 'csv'

# Service object responsible for exporting raw test_result series for a Task.
# Wide format: first column is index (0-based position of each result), then one column per handler_type.
# Missing values (unequal series lengths) are left blank.
class TaskSeriesCsvExporter
  # @param task [Task]
  # @param metric [String] either 'duration' or 'memory'
  def initialize(task:, metric:)
    @task = task
    @metric = metric
    validate_metric!
  end

  # Generates CSV string.
  def generate
    handlers = ordered_handlers
    series_map = build_series_map(handlers)
    max_len = series_map.values.map(&:length).max.to_i

    CSV.generate do |csv|
      csv << header_row(handlers)
      max_len.times do |i|
        csv << data_row(i, handlers, series_map)
      end
    end
  end

  private

  attr_reader :task, :metric

  def validate_metric!
    unless %w[duration memory].include?(metric)
      raise ArgumentError, "Unsupported metric '#{metric}'"
    end
  end

  def ordered_handlers
    # Ensure deterministic column ordering.
    task.handlers.order(:handler_type)
  end

  def build_series_map(handlers)
    handlers.index_with do |handler|
      handler.test_results.order(:id).pluck(metric_column_name)
    end
  end

  def metric_column_name
    metric == 'duration' ? 'duration' : 'memory'
  end

  def header_row(handlers)
    ['index'] + handlers.map(&:handler_type)
  end

  def data_row(index, handlers, series_map)
    row = [index]
    handlers.each do |handler|
      values = series_map[handler]
      if index < values.length
        row << format_value(values[index])
      else
        row << nil
      end
    end
    row
  end

  def format_value(val)
    return nil if val.nil?
    if val.is_a?(Numeric)
      # Always display decimals with consistent precision (6 places) for easier spreadsheet comparison
      return format('%.6f', val)
    end
    val.to_s
  end
end
