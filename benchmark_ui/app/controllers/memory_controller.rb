class MemoryController < ApplicationController
  def index
    tasks = Task.where(selected: true).includes(handlers: :statistics).order(:id)

    @series_by_handler = {}

    tasks.each do |task|
      per_page = task.respond_to?(:per_page) ? task.per_page : nil
      next unless per_page

      task.handlers.each do |handler|
        stat = handler.memory_statistics
        next unless stat

        y = [stat.min, stat.q1, stat.median, stat.q3, stat.max]
        next if y.compact.blank?

        @series_by_handler[handler.handler_type] ||= []
        @series_by_handler[handler.handler_type] << {
          x: per_page,
          y: y
        }
      end
    end
  end

  def selected_csv
    tasks = Task.where(selected: true)
    csv = SelectedTasksMemoryCsvExporter.new(tasks: tasks).generate
    send_data csv, filename: "selected_tasks_memory_#{Time.now.utc.strftime('%Y%m%d%H%M%S')}.csv",
              type: 'text/csv'
  end
end

