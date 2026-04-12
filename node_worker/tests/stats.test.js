import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateStatistics } from '../stats.js';

test('calculateStatistics even sample', () => {
  const stats = calculateStatistics([40, 10, 30, 20]);
  assert.equal(stats.min, 10);
  assert.equal(stats.max, 40);
  assert.equal(stats.mean, 25);
  assert.equal(stats.median, 25);
  assert.equal(stats.q1, 10);
  assert.equal(stats.q3, 30);
  assert.ok(Math.abs(stats.standard_deviation - 11.180339887) < 1e-9);
});

test('calculateStatistics odd sample', () => {
  const stats = calculateStatistics([3, 1, 2]);
  assert.equal(stats.min, 1);
  assert.equal(stats.max, 3);
  assert.equal(stats.median, 2);
  assert.equal(stats.q1, 1);
  assert.equal(stats.q3, 3);
});

test('calculateStatistics empty sample', () => {
  const stats = calculateStatistics([]);
  Object.values(stats).forEach((value) => {
    assert.equal(value, null);
  });
});
