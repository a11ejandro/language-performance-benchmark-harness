# frozen_string_literal: true

module Article
  module Tooling
    class SeedSamples
      def self.call(rows:, seed:, dist:)
        ENV["ROWS"] = rows.to_s
        ENV["SEED"] = seed.to_s
        ENV["DIST"] = dist.to_s

        Rails.application.load_seed
      end
    end
  end
end
