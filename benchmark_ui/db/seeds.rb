# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end


# Deterministic sample generator for reproducible benchmarks.
# Configure via env:
# - ROWS (default: 100000)
# - SEED (default: 123)
# - DIST (survey|uniform|normal) (default: survey)

rows = (ENV["ROWS"] || "100000").to_i
seed = (ENV["SEED"] || "123").to_i
dist = (ENV["DIST"] || "survey").to_s

puts "[db:seed] seeding samples rows=#{rows} seed=#{seed} dist=#{dist}"

rng = Random.new(seed)

Sample.delete_all

batch = []
batch_size = 10_000

rows.times do |i|
  value =
    case dist
    when "uniform"
      rng.rand
    when "normal"
      # Box–Muller transform; clamp to [0, 1]
      u1 = [rng.rand, 1e-12].max
      u2 = rng.rand
      z0 = Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
      v = 0.5 + 0.15 * z0
      [[v, 0.0].max, 1.0].min
    else
      # "survey": discrete-like distribution with slight noise.
      # Produces values near 1..5 with more mass in the middle.
      base = rng.rand
      bucket =
        if base < 0.10
          1
        elsif base < 0.35
          2
        elsif base < 0.70
          3
        elsif base < 0.90
          4
        else
          5
        end
      bucket + (rng.rand - 0.5) * 0.1
    end

  batch << { value: value }

  if batch.length >= batch_size
    Sample.insert_all!(batch)
    batch.clear
    puts "  inserted #{i + 1}/#{rows}" if ((i + 1) % 50_000).zero?
  end
end

Sample.insert_all!(batch) if batch.any?

puts "[db:seed] done. samples=#{Sample.count}"
