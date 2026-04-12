require 'csv'

# Exports raw duration test_result series for all selected tasks in long format.
# Columns: task, handler_type, index, duration
class SelectedTasksDurationCsvExporter
  def initialize(tasks:)
    @tasks = tasks
  end

  def generate
    CSV.generate do |csv|
      csv << %w[task handler_type index duration]
      tasks.order(:name).includes(handlers: { test_runs: :test_results }).find_each do |task|
        task.handlers.order(:handler_type).each do |handler|
          series = handler.test_results.order(:id).pluck(:duration)
          series.each_with_index do |val, idx|
            csv << [task.name, handler.handler_type, idx, format_value(val)]
          end
        end
      end
    end
  end

  private

  attr_reader :tasks

  def format_value(val)
    return nil if val.nil?
    return format('%.6f', val) if val.is_a?(Numeric)
    val.to_s
  end
end
