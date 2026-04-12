import { Pool } from 'pg';
import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Load env early so imports that rely on process.env see correct values.
const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Load benchmark_ui env first (shared DB credentials), then local overrides.
dotenv.config({ path: path.resolve(__dirname, '../benchmark_ui/.env') });
dotenv.config({ path: path.resolve(__dirname, '.env') });

let poolConfig; // lazily built after env loaded
let pool;       // lazily instantiated Pool

function getPool() {
  if (!pool) {
    poolConfig = buildConfig();
    pool = new Pool(poolConfig);
    if (process.env.NODE_WORKER_LOG_POOL_CONFIG === '1') {
      // Safe log (omit password)
      const { password, connectionString, ...rest } = poolConfig || {};
      console.log('[node_worker] pg pool config', {
        ...rest,
        hasPassword: Boolean(password || (connectionString && /:\/\/.+:.+@/.test(connectionString))),
      });
    }
  }
  return pool;
}

function buildConfig() {
  if (process.env.DATABASE_URL) {
    return {
      connectionString: process.env.DATABASE_URL,
      ...poolTunables(),
    };
  }

  const user = normalizeString(process.env.POSTGRES_USER);
  const rawPassword = process.env.POSTGRES_PASSWORD;
  // Ensure password is a non-empty string; if provided but not a string, coerce.
  let password = null;
  if (rawPassword != null && rawPassword !== '') {
    if (typeof rawPassword === 'string') {
      password = rawPassword;
    } else {
      password = String(rawPassword);
    }
  }

  return {
    host: process.env.POSTGRES_HOST || 'localhost',
    port: Number(process.env.POSTGRES_PORT || 5432),
    ...(user ? { user } : {}),
    ...(password ? { password } : {}),
    database: process.env.POSTGRES_DB || 'benchmark_development',
    ...poolTunables(),
  };
}

function poolTunables() {
  return {
    max: positiveInt(process.env.PG_POOL_MAX) ?? 2, // allow a little parallelism
    idleTimeoutMillis: positiveInt(process.env.PG_POOL_IDLE_TIMEOUT_MS) ?? 5000,
    connectRetries: positiveInt(process.env.PG_POOL_CONNECT_RETRIES) ?? 5,
    connectRetryDelayMs: positiveInt(process.env.PG_POOL_CONNECT_RETRY_DELAY_MS) ?? 500,
  };
}

export async function withClient(fn) {
  let attempt = 0;
  let lastError;
  const p = getPool();
  const cfg = poolConfig; // set by getPool
  const retries = cfg.connectRetries || 1;
  const delayMs = cfg.connectRetryDelayMs || 0;

  while (attempt < retries) {
    attempt += 1;
    try {
      const client = await p.connect();
      try {
        return await fn(client);
      } finally {
        client.release();
      }
    } catch (err) {
      lastError = err;
      if (!isPoolExhausted(err)) {
        throw err;
      }
      if (attempt >= retries) {
        break;
      }
      await delay(delayMs || 0);
    }
  }
  throw lastError;
}

export async function testRunExists(client, testRunId) {
  const { rows } = await client.query('SELECT 1 FROM test_runs WHERE id = $1 LIMIT 1', [testRunId]);
  return rows.length > 0;
}

export async function fetchTaskWindow(client, testRunId) {
  const q = `
    SELECT tasks.page, tasks.per_page
    FROM tasks
    JOIN handlers ON handlers.task_id = tasks.id
    JOIN test_runs ON test_runs.handler_id = handlers.id
    WHERE test_runs.id = $1
    LIMIT 1
  `;

  const { rows } = await client.query(q, [testRunId]);
  const row = rows[0] || {};
  return {
    page: normalizePositiveInt(row.page, 1),
    perPage: normalizePositiveInt(row.per_page, 1),
  };
}

export async function fetchSamples(client, page, perPage) {
  const { limit, offset } = windowLimitOffset(page, perPage);
  const { rows } = await client.query(
    'SELECT value FROM samples ORDER BY id ASC LIMIT $1 OFFSET $2',
    [limit, offset],
  );
  return rows.map((row) => (row.value !== null ? Number(row.value) : null)).filter((v) => v !== null);
}

export async function insertResult(client, testRunId, stats, duration, memory) {
  const q = `
    INSERT INTO test_results
      (test_run_id, mean, median, q1, q3, min, max, standard_deviation, duration, memory, created_at, updated_at)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW(),NOW())
  `;

  await client.query(q, [
    testRunId,
    stats.mean,
    stats.median,
    stats.q1,
    stats.q3,
    stats.min,
    stats.max,
    stats.standard_deviation,
    duration,
    memory,
  ]);
}

function windowLimitOffset(page, perPage) {
  const limit = perPage > 0 ? perPage : 1;
  const pg = page > 0 ? page : 1;
  return { limit, offset: (pg - 1) * limit };
}

function normalizePositiveInt(value, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return Math.trunc(parsed);
}

function positiveInt(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return null;
  }
  return Math.trunc(parsed);
}

function normalizeString(value) {
  if (value == null) return null;
  return typeof value === 'string' ? value : String(value);
}

function isPoolExhausted(err) {
  return err?.code === '53300' || /too many clients/i.test(err?.message || '');
}

function delay(ms) {
  if (!ms || ms <= 0) {
    return Promise.resolve();
  }
  return new Promise((resolve) => setTimeout(resolve, ms));
}
