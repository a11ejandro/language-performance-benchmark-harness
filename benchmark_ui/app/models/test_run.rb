class TestRun < ApplicationRecord
  belongs_to :handler, touch: true
  has_many :test_results

  after_save
end
