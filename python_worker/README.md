# Python Worker (Celery)

A Celery-based worker that mirrors the Ruby `RubyWorker#perform` behavior:
- Reads all `samples.value` from Postgres
- Computes min, q1, median, q3, max, mean, population stddev
- Measures duration and peak allocated memory (via `tracemalloc`)
- Inserts a `test_results` row for the provided `test_run_id`

## Setup

```bash
cd python_worker
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Configuration

Environment is auto-loaded from:
- `../benchmark_ui/.env` (Rails app)
- `./.env` (local overrides)

Expected variables (same as Rails):
- `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- or `DATABASE_URL`
- `REDIS_URL` (e.g., `redis://localhost:6379/0`)
- `WORKER_QUEUE` (default: `python`) – queue name for Celery worker and enqueue script

## Run the worker

```bash
# inside python_worker with venv activated
celery -A celery_app.app worker -Q ${WORKER_QUEUE:-python} -l info
```

## Run the enqueue API (used by Rails)

```bash
# start the HTTP bridge that Rails calls
flask --app server run --host ${PYTHON_WORKER_HOST:-127.0.0.1} --port ${PYTHON_WORKER_PORT:-5000}
```

Rails expects the endpoint to be available at `POST ${PYTHON_WORKER_URL:-http://127.0.0.1:5000/enqueue}`.

## Enqueue a job

```bash
# Enqueue a single job for a given test_run_id
python enqueue.py 123
```

This uses the Celery queue and does not consume Sidekiq jobs. It shares the same Redis instance but on a separate queue namespace handled by Celery.

## Tests (Docker)

From `rails_8/`:

- `docker compose build python_worker`
- `docker compose run --rm python_worker python -m unittest discover -s tests -p 'test_*.py'`
