import { createClient } from 'redis';
import { processTestRun } from './worker_logic.js';

export async function runService() {
  const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379/0';
  const queueName = process.env.WORKER_QUEUE || 'default';
  const queueKey = `queue:${queueName}`;

  const client = createClient({ url: redisUrl });
  client.on('error', (err) => {
    console.error('[redis] error', err);
  });
  await client.connect();
  console.log(`[node_worker] listening on ${queueKey} via ${redisUrl}`);

  while (true) {
    try {
      const result = await client.sendCommand(['BRPOP', queueKey, '5']);
      if (!result) {
        continue;
      }
      const [, payload] = result;
      let job;
      try {
        job = JSON.parse(payload);
      } catch (err) {
        console.warn('[node_worker] invalid JSON job', err);
        continue;
      }
      if (!shouldProcess(job)) {
        continue;
      }
      const id = parseJobId(job);
      if (!id) {
        console.warn('[node_worker] missing job id in payload');
        continue;
      }
      try {
        await processTestRun(id);
      } catch (err) {
        console.error(`[node_worker] job ${id} failed`, err);
      }
    } catch (err) {
      console.error('[node_worker] redis BRPOP failed', err);
      await delay(2000);
    }
  }
}

function shouldProcess(job) {
  const allowed = new Set(['RubyWorker', 'GoWorker', 'PythonWorker', 'NodeWorker']);
  return allowed.has(job?.class);
}

function parseJobId(job) {
  if (!job?.args || job.args.length === 0) {
    return null;
  }
  const raw = job.args[0];
  if (typeof raw === 'number') {
    return raw;
  }
  if (typeof raw === 'string') {
    const parsed = Number(raw);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
