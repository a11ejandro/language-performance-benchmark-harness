class ComparisonRun < ApplicationRecord
  STATUSES = %w[pending running completed failed].freeze

  has_many :comparison_statistics, dependent: :destroy

  validates :baseline_label, :baseline_path, :candidate_label, :candidate_path, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
end