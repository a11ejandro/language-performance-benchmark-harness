import test from 'node:test';
import assert from 'node:assert/strict';
import { measurePeakResidentMemory } from '../memory.js';

const originalMemoryUsage = process.memoryUsage;

test('measurePeakResidentMemory tracks maximum rss', async () => {
  const readings = [100_000_000, 150_000_000, 200_000_000];
  process.memoryUsage = () => ({
    rss: readings.length ? readings.shift() : 200_000_000,
    heapTotal: 0,
    heapUsed: 0,
    external: 0,
    arrayBuffers: 0,
  });

  try {
    const { result, peak } = await measurePeakResidentMemory(async () => {
      await new Promise((resolve) => setTimeout(resolve, 20));
      return 'ok';
    });
    assert.equal(result, 'ok');
    assert.equal(peak, 200_000_000);
  } finally {
    process.memoryUsage = originalMemoryUsage;
  }
});
