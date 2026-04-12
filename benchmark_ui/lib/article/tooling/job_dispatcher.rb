# frozen_string_literal: true

module Article
  module Tooling
    class JobDispatcher
      def self.enqueue(handler_type, test_run_id, mode)
        case handler_type
        when "ruby"
          enqueue_ruby(test_run_id, mode)
        when "go"
          enqueue_go(test_run_id)
        when "node"
          enqueue_node(test_run_id)
        when "python"
          enqueue_python(test_run_id)
        else
          raise ArgumentError, "Unknown handler type: #{handler_type.inspect}"
        end
      end

      def self.enqueue_ruby(test_run_id, mode)
        if mode == "inline"
          RubyWorker.new.perform(test_run_id)
          :inline
        else
          RubyWorker.perform_async(test_run_id)
          :enqueued
        end
      end

      def self.enqueue_go(test_run_id)
        Sidekiq::Client.push("class" => "GoWorker", "queue" => "go", "args" => [test_run_id])
        :enqueued
      end

      def self.enqueue_node(test_run_id)
        Sidekiq::Client.push("class" => "NodeWorker", "queue" => "node", "args" => [test_run_id])
        :enqueued
      end

      def self.enqueue_python(test_run_id)
        PythonWorkerClient.enqueue(test_run_id)
        :enqueued
      end

      private_class_method :enqueue_ruby, :enqueue_go, :enqueue_node, :enqueue_python
    end
  end
end
