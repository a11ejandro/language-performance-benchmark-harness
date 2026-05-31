class ComparisonRunsController < ApplicationController
  def index
    @comparison_runs = ComparisonRun.order(created_at: :desc)
  end

  def show
    @comparison_run = ComparisonRun.find(params[:id])
    @statistics_by_metric = @comparison_run.comparison_statistics
                                           .order(:metric, :handler_type, :per_page)
                                           .group_by(&:metric)
  end
end
