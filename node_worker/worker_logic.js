import * as db from './db.js';
import { calculateStatistics } from './stats.js';
import { measurePeakResidentMemory } from './memory.js';

export function createProcessTestRun({
  dbModule = db,
  calculateStatisticsFn = calculateStatistics,
  measurePeakResidentMemoryFn = measurePeakResidentMemory,
} = {}) {
  return async function processTestRun(testRunId) {
    if (!Number.isFinite(Number(testRunId))) {
      throw new Error('invalid test_run_id');
    }
    const id = Number(testRunId);
    return dbModule.withClient(async (client) => {
      const exists = await dbModule.testRunExists(client, id);
      if (!exists) {
        throw new Error(`test_runs id ${id} not found`);
      }
      const { page, perPage } = await dbModule.fetchTaskWindow(client, id);
      const values = await dbModule.fetchSamples(client, page, perPage);
      const { result, peak } = await measurePeakResidentMemoryFn(async () => {
        const start = process.hrtime.bigint();
        const stats = calculateStatisticsFn(values);
        const duration = Number(process.hrtime.bigint() - start) / 1e9;
        return { stats, duration };
      });

      const { stats, duration } = result;
      await dbModule.insertResult(client, id, stats, duration, peak);
      return { id, duration, memory: peak };
    });
  };
}

export const processTestRun = createProcessTestRun();
