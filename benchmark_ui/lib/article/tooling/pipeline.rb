# frozen_string_literal: true

module Article
  module Tooling
    class Pipeline
      def self.call(config)
        puts "[article:generate_all] Configuration:"
        puts "  samples: rows=#{config.rows} seed=#{config.seed} dist=#{config.dist}"
        puts "  tasks: per_pages=#{config.per_pages} runs=#{config.runs} page=#{config.page}"
        puts "  execution: handlers=#{config.handlers} mode=#{config.mode} schedule=#{config.schedule}"
        puts "  waiting: wait=#{config.wait} timeout=#{config.wait_timeout}s poll=#{config.wait_poll}s"

        SeedSamples.call(rows: config.rows, seed: config.seed, dist: config.dist)
        ReplaceTasks.call(per_pages: config.per_page_integers, runs: config.runs, page: config.page)

        BenchmarkRunner.new(config).execute!

        should_export = inline_ruby_only?(config) || config.wait
        return :skipped unless should_export

        export_selected_csv
        generate_results_summary
        generate_figures

        :exported
      end

      def self.inline_ruby_only?(config)
        config.mode == "inline" && config.handler_list == ["ruby"]
      end

      def self.export_selected_csv
        Rake::Task["article:export_selected_csv"].reenable
        Rake::Task["article:export_selected_csv"].invoke
        puts "[article:generate_all] exported CSV"
      end

      def self.generate_figures
        Rake::Task["article:generate_figures"].reenable
        Rake::Task["article:generate_figures"].invoke
        puts "[article:generate_all] generated figures"
      end

      def self.generate_results_summary
        Rake::Task["article:generate_results_summary"].reenable
        Rake::Task["article:generate_results_summary"].invoke
        puts "[article:generate_all] generated results summary"
      end

      private_class_method :inline_ruby_only?, :export_selected_csv, :generate_results_summary, :generate_figures
    end
  end
end
