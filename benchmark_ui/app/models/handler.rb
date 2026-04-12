class Handler < ApplicationRecord
  TYPES = %w[ruby go python node].freeze

  belongs_to :task
  has_many :test_runs, dependent: :destroy
  has_many :test_results, through: :test_runs
  has_many :statistics, dependent: :destroy

  after_save :save_statistics, if: :complete?

  validates :handler_type, presence: true, inclusion: { in: TYPES }

  def duration_statistics
    statistics.find_by(metric: 'duration')
  end

  def memory_statistics
    statistics.find_by(metric: 'memory')
  end

  def complete?
    return false if test_runs.count.zero?

    !test_runs.joins(:test_results).where(test_results: { id: nil }).exists?
  end

  def save_statistics
    duration = statistics.find_or_initialize_by(metric: 'duration')
    duration.assign_attributes(CalculateStatistics.call(test_results.pluck(:duration)))
    duration.save if duration.changed?

    memory = statistics.find_or_initialize_by(metric: 'memory')
    memory.assign_attributes(CalculateStatistics.call(test_results.pluck(:memory)))
    memory.save if memory.changed?
  end
end
