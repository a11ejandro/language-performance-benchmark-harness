# frozen_string_literal: true

module Article
  module Tooling
    class CompletionWaiter
      def self.wait_for(handler_ids:, expected_results:, timeout_seconds:, poll_seconds:, queue_names: [])
        start = Time.now
        last_count = -1
        last_log_at = Time.at(0)
        log_every_seconds = [10.0, poll_seconds.to_f].max

        loop do
          count = TestResult.joins(:test_run).where(test_runs: { handler_id: handler_ids }).count

          now = Time.now
          should_log = (count != last_count) || (now - last_log_at) >= log_every_seconds

          if should_log
            elapsed = (now - start).round(1)
            extras = queue_depth_summary(queue_names)
            suffix = extras.empty? ? "" : " | #{extras}"
            puts "[waiting] progress #{count}/#{expected_results} elapsed=#{elapsed}s#{suffix}"
            last_count = count
            last_log_at = now
          end

          return count if count >= expected_results

          if (now - start) > timeout_seconds
            raise "Timeout waiting for results: #{count}/#{expected_results} after #{timeout_seconds}s"
          end

          sleep poll_seconds
        end
      end

      def self.queue_depth_summary(queue_names)
        names = Array(queue_names).map(&:to_s).map(&:strip).reject(&:empty?)
        return "" if names.empty?
        return "" unless defined?(Sidekiq)

        depths = Sidekiq.redis do |redis|
          names.map do |q|
            key = "queue:#{q}"
            "#{key}=#{redis.llen(key)}"
          end
        end

        depths.join(" ")
      rescue StandardError
        ""
      end

      private_class_method :queue_depth_summary
    end
  end
end
