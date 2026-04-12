export function calculateStatistics(samples) {
  if (!samples || samples.length === 0) {
    return {
      min: null,
      max: null,
      mean: null,
      median: null,
      q1: null,
      q3: null,
      standard_deviation: null,
    };
  }

  const sorted = [...samples].map(Number).sort((a, b) => a - b);
  const n = sorted.length;
  const min = sorted[0];
  const max = sorted[n - 1];
  const mean = sorted.reduce((sum, v) => sum + v, 0) / n;
  const median = n % 2 === 1 ? sorted[Math.floor(n / 2)] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2;

  const idx = (fraction) => {
    const i = Math.max(Math.min(Math.ceil(fraction) - 1, n - 1), 0);
    return i;
  };

  const q1 = sorted[idx(n / 4)];
  const q3 = sorted[idx((3 * n) / 4)];

  const variance = sorted.reduce((acc, value) => {
    const diff = value - mean;
    return acc + diff * diff;
  }, 0) / n;
  const standardDeviation = Math.sqrt(variance);

  return {
    min,
    max,
    mean,
    median,
    q1,
    q3,
    standard_deviation: standardDeviation,
  };
}
