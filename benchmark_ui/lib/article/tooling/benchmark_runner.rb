# frozen_string_literal: true

module Article
  module Tooling
    class BenchmarkRunner
      attr_reader :config, :enqueued_count, :inline_count

      def initialize(config)
        @config = config
        @enqueued_count = 0
        @inline_count = 0
      end

      def execute!
        tasks = Task.where(selected: true).order(:name)

        if config.schedule == "serial_by_handler"
          execute_serial_by_handler(tasks)
        else
          execute_parallel(tasks)
        end

        puts "[orchestrator] inline_completed=#{@inline_count} enqueued=#{@enqueued_count}"
      end

      private

      def execute_serial_by_handler(tasks)
        config.handler_list.each do |handler_type|
          puts "[orchestrator] starting handler=#{handler_type}"

          handler_ids, expected_results = create_and_enqueue_for_handler(tasks, handler_type)

          wait_if_needed(handler_type, handler_ids, expected_results)
        end
      end

      def execute_parallel(tasks)
        tasks.find_each do |task|
          config.handler_list.each do |handler_type|
            create_and_enqueue_for_task(task, handler_type)
          end
        end
      end

      def create_and_enqueue_for_handler(tasks, handler_type)
        handler_ids = []
        expected_results = 0

        tasks.find_each do |task|
          handler = Handler.create!(task: task, handler_type: handler_type)
          handler_ids << handler.id
          expected_results += task.runs

          enqueue_runs_for_handler(handler, task.runs)
        end

        [handler_ids, expected_results]
      end

      def create_and_enqueue_for_task(task, handler_type)
        handler = Handler.create!(task: task, handler_type: handler_type)
        enqueue_runs_for_handler(handler, task.runs)
      end

      def enqueue_runs_for_handler(handler, runs)
        runs.times do |run|
          test_run = TestRun.create!(handler: handler, consequent_number: run)
          outcome = JobDispatcher.enqueue(handler.handler_type, test_run.id, config.mode)

          outcome == :inline ? @inline_count += 1 : @enqueued_count += 1
        end
      end

      def wait_if_needed(handler_type, handler_ids, expected_results)
        return unless config.wait
        return if inline_ruby_only?(handler_type)

        puts "[orchestrator] waiting handler=#{handler_type} expected_results=#{expected_results}"
        queue_names = sidekiq_queue_names_for(handler_type)
        CompletionWaiter.wait_for(
          handler_ids: handler_ids,
          expected_results: expected_results,
          timeout_seconds: config.wait_timeout,
          poll_seconds: config.wait_poll,
          queue_names: queue_names
        )
      end

      def inline_ruby_only?(handler_type)
        config.mode == "inline" && handler_type == "ruby"
      end

      def sidekiq_queue_names_for(handler_type)
        case handler_type
        when "ruby"
          ["default"]
        when "go"
          ["go"]
        when "node"
          ["node"]
        else
          []
        end
      end
    end
  end
end
