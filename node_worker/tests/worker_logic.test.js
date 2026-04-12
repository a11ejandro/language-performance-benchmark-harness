import test from 'node:test';
import assert from 'node:assert/strict';

import { createProcessTestRun } from '../worker_logic.js';

test('processTestRun rejects invalid test_run_id', async () => {
  const processTestRun = createProcessTestRun({
    dbModule: {
      withClient: async () => {
        throw new Error('should not be called');
      },
    },
  });

  await assert.rejects(() => processTestRun('nope'), /invalid test_run_id/);
});

test('processTestRun errors when test run missing', async () => {
  const calls = [];
  const fakeClient = { name: 'client' };

  const processTestRun = createProcessTestRun({
    dbModule: {
      withClient: async (fn) => fn(fakeClient),
      testRunExists: async (client, id) => {
        calls.push(['testRunExists', client, id]);
        return false;
      },
    },
  });

  await assert.rejects(() => processTestRun(123), /test_runs id 123 not found/);
  assert.deepEqual(calls, [['testRunExists', fakeClient, 123]]);
});

test('processTestRun inserts result and returns summary', async () => {
  const fakeClient = { name: 'client' };
  const calls = [];

  const processTestRun = createProcessTestRun({
    dbModule: {
      withClient: async (fn) => fn(fakeClient),
      testRunExists: async (client, id) => {
        calls.push(['testRunExists', client, id]);
        return true;
      },
      fetchTaskWindow: async (client, id) => {
        calls.push(['fetchTaskWindow', client, id]);
        return { page: 2, perPage: 3 };
      },
      fetchSamples: async (client, page, perPage) => {
        calls.push(['fetchSamples', client, page, perPage]);
        return [1, 2, 3];
      },
      insertResult: async (client, id, stats, duration, peak) => {
        calls.push(['insertResult', client, id, stats, duration, peak]);
      },
    },
    calculateStatisticsFn: (values) => {
      calls.push(['calculateStatistics', values]);
      return { mean: 2 };
    },
    measurePeakResidentMemoryFn: async (fn) => {
      const result = await fn();
      return { result, peak: 456 };
    },
  });

  const out = await processTestRun('99');

  assert.equal(out.id, 99);
  assert.equal(out.memory, 456);
  assert.equal(typeof out.duration, 'number');

  const insert = calls.find((c) => c[0] === 'insertResult');
  assert.ok(insert, 'expected insertResult call');
  assert.equal(insert[2], 99);
  assert.deepEqual(insert[3], { mean: 2 });
  assert.equal(insert[5], 456);
});
