class ComparisonStatistic < ApplicationRecord
  belongs_to :comparison_run

  validates :metric, presence: true, inclusion: { in: Statistic::METRICS }
  validates :handler_type, presence: true, inclusion: { in: Handler::TYPES }
  validates :per_page, presence: true
  validates_uniqueness_of :per_page, scope: %i[comparison_run_id metric handler_type]
end