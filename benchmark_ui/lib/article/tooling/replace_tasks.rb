# frozen_string_literal: true

module Article
  module Tooling
    class ReplaceTasks
      def self.call(per_pages:, runs:, page:)
        puts "[article:setup_tasks] per_pages=#{per_pages.inspect} runs=#{runs} page=#{page}"

        Statistic.delete_all
        TestResult.delete_all
        TestRun.delete_all
        Handler.delete_all
        Task.delete_all

        per_pages.each do |per_page|
          Task.create!(
            name: per_page.to_s,
            page: page,
            per_page: per_page,
            runs: runs,
            selected: true
          )
        end

        puts "[article:setup_tasks] done. tasks=#{Task.count}"
      end
    end
  end
end
