# Node Worker

A Node.js implementation that mirrors the Ruby/Golang workers. It can run a single `test_runs` job or listen to the Sidekiq queue and process jobs continuously.

## Requirements

- Node.js 24+
- Access to the same PostgreSQL and Redis instances used by the Rails app

Install dependencies once:

```bash
cd node_worker
npm install
```

## Configuration

Environment variables match the Rails/go workers. The script automatically loads `../benchmark_ui/.env` and `node_worker/.env` if present.

PostgreSQL:

- `POSTGRES_HOST` (default `localhost`)
- `POSTGRES_PORT` (default `5432`)
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB` (e.g. `benchmark_development`)
- or `DATABASE_URL`
- `PG_POOL_MAX` (default `1`) to cap the Node worker’s open connections
- `PG_POOL_IDLE_TIMEOUT_MS` (default `5000`) to close idle connections sooner
- `PG_POOL_CONNECT_RETRIES` (default `5`) to retry when Postgres is out of slots
- `PG_POOL_CONNECT_RETRY_DELAY_MS` (default `500`) wait time between retries

Redis:

- `REDIS_URL` (default `redis://localhost:6379/0`)
- `WORKER_QUEUE` (default `default`, so Sidekiq’s `queue:default`)

## Usage

Build/install deps (once):

```bash
cd node_worker
npm install
```

Run a single job:

```bash
node worker.js --test-run-id 123
# or positional
node worker.js 123
```

Run as a background service that pulls jobs from Redis:

```bash
node worker.js --service
# or simply
node worker.js
```

The worker:

1. Validates the `test_runs` row exists.
2. Reads the associated task’s `page` / `per_page`.
3. Fetches that window of `samples`, computes statistics, and measures wall-clock + peak RSS just like the other workers.
4. Inserts a `test_results` record with the computed stats, duration (seconds), and memory (bytes).

During service mode it listens for `RubyWorker`, `GoWorker`, `PythonWorker`, or `NodeWorker` jobs so you can enqueue from Rails without changes.

## Tests (Docker)

From `rails_8/`:

- `docker compose build node_worker`
- `docker compose run --rm node_worker node --test`
