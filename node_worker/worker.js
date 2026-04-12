#!/usr/bin/env node
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import { processTestRun } from './worker_logic.js';
import { runService } from './sidekiq.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, '../benchmark_ui/.env') });
dotenv.config({ path: path.resolve(__dirname, '.env') });

async function main() {
  let parsed;
  try {
    parsed = parseArgs(process.argv.slice(2));
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
  const { service, testRunId } = parsed;

  if (service || (!testRunId && process.argv.length === 2)) {
    await runService();
    return;
  }

  if (testRunId == null) {
    console.error('Usage: node worker.js --test-run-id <id>');
    process.exit(1);
  }

  try {
    const result = await processTestRun(testRunId);
    console.log(`[node_worker] processed test_run=${result.id} duration=${result.duration.toFixed(6)}s memory_bytes=${Math.round(result.memory)}`);
  } catch (err) {
    console.error('[node_worker] error', err);
    process.exit(1);
  }
}

function parseArgs(args) {
  let service = false;
  let testRunId = null;
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === '--service') {
      service = true;
    } else if (arg === '--test-run-id' || arg === '-i') {
      const next = args[i + 1];
      if (!next) {
        throw new Error('--test-run-id requires a value');
      }
      testRunId = Number(next);
      i += 1;
    } else if (!arg.startsWith('-') && testRunId == null) {
      testRunId = Number(arg);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return { service, testRunId };
}

main();
