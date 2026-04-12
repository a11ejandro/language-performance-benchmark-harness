# frozen_string_literal: true

module Article
  module Tooling
    class Configuration
      DEFAULTS = {
        rows: "100000",
        seed: "123",
        dist: "survey",
        per_pages: "1,10,25,50,100,250,500,1000,10000,100000",
        runs: "30",
        page: "1",
        handlers: "ruby,go,python,node",
        mode: "enqueue",
        schedule: "serial_by_handler",
        wait_timeout: 7200,
        wait_poll: 2.0
      }.freeze

      attr_reader :rows, :seed, :dist, :per_pages, :runs, :page,
                  :handlers, :mode, :schedule, :wait, :wait_timeout, :wait_poll

      def initialize(args = {}, env = ENV)
        @rows = value(args[:rows], env["ROWS"], DEFAULTS[:rows])
        @seed = value(args[:seed], env["SEED"], DEFAULTS[:seed])
        @dist = value(args[:dist], env["DIST"], DEFAULTS[:dist])
        @per_pages = value(args[:per_pages], env["PER_PAGES"], DEFAULTS[:per_pages])
        @runs = value(args[:runs], env["RUNS"], DEFAULTS[:runs]).to_i
        @page = value(args[:page], env["PAGE"], DEFAULTS[:page]).to_i
        @handlers = value(args[:handlers], env["HANDLERS"], DEFAULTS[:handlers])
        @mode = value(args[:mode], env["MODE"], DEFAULTS[:mode])
        @schedule = value(args[:schedule], env["SCHEDULE"], DEFAULTS[:schedule])

        wait_default = @schedule == "serial_by_handler" ? "true" : "false"
        @wait = value(args[:wait], env["WAIT"], wait_default) == "true"
        @wait_timeout = value(args[:wait_timeout], env["WAIT_TIMEOUT_SECONDS"], DEFAULTS[:wait_timeout]).to_i
        @wait_poll = value(args[:wait_poll], env["WAIT_POLL_SECONDS"], DEFAULTS[:wait_poll]).to_f
      end

      def per_page_integers
        @per_pages.split(",").map(&:strip).reject(&:empty?).map(&:to_i)
      end

      def handler_list
        @handlers.split(",").map(&:strip).reject(&:empty?)
      end

      private

      def value(arg, env_val, default)
        (arg || env_val || default).to_s
      end
    end
  end
end
