# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib", "article", "tooling", "configuration").to_s

RSpec.describe Article::Tooling::Configuration do
  describe "defaults" do
    it "uses schedule-based WAIT default" do
      config = described_class.new({ schedule: "serial_by_handler" }, {})
      expect(config.wait).to eq(true)

      config = described_class.new({ schedule: "parallel" }, {})
      expect(config.wait).to eq(false)
    end

    it "parses lists and integers" do
      config = described_class.new({ per_pages: "1, 10, 25" }, {})
      expect(config.per_page_integers).to eq([1, 10, 25])
    end
  end

  describe "env overrides" do
    it "prefers env vars when args not provided" do
      env = {
        "ROWS" => "42",
        "SEED" => "7",
        "DIST" => "survey",
        "PER_PAGES" => "3,4",
        "RUNS" => "2",
        "PAGE" => "5",
        "HANDLERS" => "ruby",
        "MODE" => "inline",
        "SCHEDULE" => "serial_by_handler",
        "WAIT" => "false"
      }

      config = described_class.new({}, env)

      expect(config.rows).to eq("42")
      expect(config.seed).to eq("7")
      expect(config.runs).to eq(2)
      expect(config.page).to eq(5)
      expect(config.handler_list).to eq(["ruby"])
      expect(config.mode).to eq("inline")
      expect(config.wait).to eq(false)
      expect(config.per_page_integers).to eq([3, 4])
    end
  end
end
