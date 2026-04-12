class Task < ApplicationRecord
  has_many :handlers, dependent: :destroy
  has_many :statistics, through: :handlers

  def statistics_by_metric
    Statistic::METRICS.each_with_object({}) do |metric, acc|
      acc[metric] = statistics.includes(:handler).where(metric:).map do |s|
        [s.handler.handler_type, s.attributes.slice(*Statistic::MATH_ATTRIBUTES)]
      end.to_h
    end
  end
end
