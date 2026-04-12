class Statistic < ApplicationRecord
  MATH_ATTRIBUTES = %w[standard_deviation min max mean median q1 q3].freeze
  METRICS = %w[duration memory].freeze

  belongs_to :handler

  validates_uniqueness_of :metric, scope: :handler_id
end
