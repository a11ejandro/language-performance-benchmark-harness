const SAMPLING_INTERVAL_MS = 10;

export async function measurePeakResidentMemory(fn) {
  let peak = process.memoryUsage().rss;
  let running = true;

  const sampler = setInterval(() => {
    if (!running) return;
    const rss = process.memoryUsage().rss;
    if (rss > peak) {
      peak = rss;
    }
  }, SAMPLING_INTERVAL_MS);

  try {
    const result = await fn();
    running = false;
    clearInterval(sampler);
    const finalRss = process.memoryUsage().rss;
    if (finalRss > peak) peak = finalRss;
    return { result, peak };
  } finally {
    running = false;
    clearInterval(sampler);
  }
}
