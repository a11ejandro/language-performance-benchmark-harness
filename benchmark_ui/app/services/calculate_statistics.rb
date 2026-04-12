class CalculateStatistics
  def self.call(samples)
    return {} if samples.empty?

    sorted = samples.sort
    n = samples.size
    max = sorted.last
    min = sorted.first
    median = n.odd? ? sorted[n / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
    mean = sorted.sum.to_f / n
    q1 = sorted[(n / 4.0).ceil - 1]
    q3 = sorted[(3 * n / 4.0).ceil - 1]

    variance = sorted.reduce(0) { |sum, value| sum + (value - mean)**2 } / n.to_f
    standard_deviation = Math.sqrt(variance)

    {
      standard_deviation:,
      min:,
      max:,
      mean:,
      median:,
      q1:,
      q3:
    }
  end
end
