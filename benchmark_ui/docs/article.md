# A Reproducible Runtime Performance Benchmark Across Ruby, Go, Python, and Node.js (via Background Job Execution)

## Abstract
We present an updated empirical comparison of four contemporary ecosystems for background job processing and computation-heavy tasks: Ruby on Rails with Sidekiq, Go with a Sidekiq-compatible Redis consumer, Python with Celery (with a small Flask enqueue bridge), and Node.js with a Sidekiq-compatible Redis consumer. Using a unified PostgreSQL schema, identical data structures (arrays / hashes / objects) and minimized framework abstractions inside workers, we measure task duration distributions, memory usage, and throughput across varying dataset slice sizes (`per_page`). We contribute: (1) a reproducible multi-language benchmark harness; (2) standardized wide and long-format CSV exports for raw result series; (3) D3-based visualizations of distributional statistics; and (4) guidance on technology selection under different latency / resource profiles. All code and data are open-source for verification and extension.

Artifact availability: https://github.com/a11ejandro/language-performance-benchmark-harness (includes Docker Compose definitions, benchmark orchestration tasks, the generated CSV/SVG artifacts under `benchmark_ui/docs/`, and the benchmark UI plus all worker implementations in one archival repository snapshot).

## 1. Introduction
Background job processing underpins web application responsiveness and scalability. While prior informal comparisons focused on small subsets of languages, engineering teams today routinely evaluate multiple ecosystems when optimizing computational workloads (e.g., aggregation, statistical transforms, ETL). This investigation delivers a controlled, reproducible cross-language study of four widely adopted stacks using current runtime versions. We emphasize: (a) methodological fairness (shared schema, identical logic paths); (b) isolation of worker-level performance by minimizing ORMs and higher abstractions; and (c) transparent raw data availability via CSV exports.

## 2. Related Work
This investigation sits at the intersection of (a) background job frameworks and their queue semantics and (b) language/runtime concurrency models. On the Ruby side, Sidekiq is a widely-used Redis-backed job processor that runs many jobs concurrently using threads in a single process [1], and its public documentation specifies the on-wire Redis job payload shape used by Sidekiq-compatible consumers [2]. Rails’ Active Job provides a standardized interface over multiple queue backends, including Sidekiq, and frames job execution as work performed off the request/response thread [3].

On the Python side, Celery is a distributed task queue with configurable worker concurrency and broker backends [4]. In this repository, a small HTTP enqueue bridge is implemented using Flask [5] to keep Rails’ enqueue path consistent while still executing the Python workload through Celery.

For the polyglot workers, the queue mechanism uses Redis lists with blocking pop semantics; Redis documents `BRPOP` as a blocking list pop primitive, which underlies the “one-job-at-a-time” consumer loops used here [6]. At the runtime level, Node.js’ official documentation describes the event loop and phases that govern execution of asynchronous callbacks [7], while CPython documents the Global Interpreter Lock (GIL) and its implications for parallel execution of Python bytecode [8]. Go’s official documentation provides the language reference entry point and further guidance on performance topics such as garbage collection [9]. Finally, the shared persistence layer is PostgreSQL, and its documentation provides authoritative definitions for SQL behavior and operational assumptions [10]. Container orchestration is implemented via Docker Compose, for which the official docs define the model used to reproduce the multi-container environment [11].

## 3. Experimental Design
### 3.1 Technologies & Versions
- Ruby / Rails:
	- Rails 8.0.2.1
	- Sidekiq 8.0.7
	- Ruby 3.4.5 (as used for this investigation)
- Go worker:
	- Go 1.22 (from `go.mod` and the container build stage)
	- Sidekiq-compatible Redis consumer (not `goworker`)
- Python worker:
	- Python 3.12 (container)
	- Celery 5.4.0, Flask 3.0.3, redis 5.0.4, psycopg2-binary 2.9.9
- Node worker:
	- Node.js 24.x (container; see Dockerfile) / `pg` 8.11.3
	- Sidekiq-compatible Redis consumer
- Data stores:
	- PostgreSQL server (Docker) 17.6
	- Redis (Docker image) 8.2

### 3.2 Hardware & Environment
 - CPU: Apple M2 Pro
 - Cores: 10 physical / 10 logical
 - RAM: 16 GiB (17,179,869,184 bytes)
 - macOS: 15.6.1 (Build 24G90)
 - Kernel/arch: Darwin 24.6.0 (arm64)
- Versions: see Section 3.1 (pinned by manifests / container images)
- Containerization: Docker / Compose for consistent runtime isolation.
- Redis: Shared instance for all queue consumers.
- PostgreSQL: Single shared database (PostgreSQL 17.6 in Docker).

### 3.3 Benchmark Task
For each page size (`per_page`), workers compute fundamental statistics (min, max, mean, median, quartiles) over a slice of survey values and record result metrics (duration, memory). Computations avoid language-specific collection utilities beyond basic loops and array operations. No caching. All statistical routines executed per task invocation.

### 3.4 Data Preparation
- Base dataset: synthetic numeric survey-like values stored in `samples.value` (float).
- Dataset size is deterministic and controlled by environment variables consumed by `bin/rails db:seed`:
	- `ROWS` (default `100000`): number of `samples` rows to generate.
	- `SEED` (default `123`): RNG seed.
	- `DIST` (default `survey`): one of:
		- `uniform`: `rand()` in $[0,1)$.
		- `normal`: Box–Muller transform with $\mu=0.5$, $\sigma=0.15$, clamped to $[0,1]$.
		- `survey`: discrete-like buckets 1..5 with mild noise $\pm 0.05$; bucket weights are 10%/25%/35%/20%/10% for 1/2/3/4/5. This yields values approximately in $[0.95, 5.05]$.
- The seed is idempotent: it deletes all rows in `samples` and reinserts deterministically in batches.
- Task set: sequence of `per_page` sizes (e.g. 1, 10, 25, 50, 100, 250, 500, 1000, 10000).
- Repetitions: each (language, per_page) pair executed N times (N configurable; default 30) for variance estimation.

### 3.5 Metrics
- Duration: Wall-clock per task.
- Memory: RSS delta / peak (approximated via runtime-specific measurement hooks).
- Throughput: Tasks per second under sustained queue load.
- Distribution statistics: Captured post-run for plotting (min, q1, median, q3, max).

### 3.6 Fairness Controls
- Identical SQL queries; minimal driver-level differences.
- Disable extraneous logging where possible.
- Concurrency is intentionally minimized to reduce cross-run interference:
	- Sidekiq runs with `concurrency: 1`.
	- Celery runs with `--concurrency=1` and `--prefetch-multiplier=1` by default in Compose.
	- Go and Node services process one job at a time in a single blocking `BRPOP` loop.
- Scheduling is configurable; the default for article generation is `SCHEDULE=serial_by_handler` with `WAIT=true`, which:
	- enqueues/runs all tasks for one handler type at a time, then waits for completion before moving to the next handler
	- avoids overlap between handler types (reducing DB/Redis contention and I/O noise)
- Queue isolation: handler types use dedicated queues where applicable (`go`, `node`, `python`), while Ruby uses Sidekiq's `default`.
- Warm-up: the harness does not currently discard warm-up runs; all configured runs are included in exports.

## 4. Implementation Overview
### 4.1 Rails / Sidekiq
UI orchestration of task creation, selection, export endpoints (`durations_csv`, `memory_csv`, long-format multi-task endpoints). Sidekiq worker executes statistical aggregation using arrays and manual loop-based calculations.

### 4.2 Go worker (Redis consumer)
Worker consumes Sidekiq-format jobs from Redis, performs direct SQL range queries, computes stats with simple slice operations, and writes results back to PostgreSQL.

### 4.3 Python / Celery
Celery tasks triggered via Redis broker, using psycopg or equivalent for direct queries, manual statistics functions for parity.

### 4.4 Node.js Worker
Sidekiq-compatible JSON job consumption from Redis; `pg` module with pooled connections. Statistics computed with pure JS arrays; memory instrumentation via process reporting (e.g., `process.memoryUsage()`).

### 4.5 Shared Schema
Tables: tasks, handlers, test_runs, test_results, statistics.
Raw series persisted in `test_results`; aggregated stats in `statistics` after handler completion.

## 5. Data Collection & Export
### 5.1 Storage
Raw durations and memory values per test result stored with timestamps. Aggregated statistical rows saved once handler series is complete.

### 5.2 CSV Export Facilities
- Per-task wide format: index + one column per handler type (duration or memory). Provided via `TaskSeriesCsvExporter`.
- Multi-task long format: task, handler_type, index, metric (separate services for durations and memory). Provided via `SelectedTasksDurationCsvExporter` and `SelectedTasksMemoryCsvExporter`.

### 5.3 JSON / API
This investigation uses CSV exports as the canonical interchange format for analysis and figure generation.

## 6. Visualization
D3 boxplot rendering for each handler type across `per_page` values (duration and memory). Figures are generated from the exported CSVs and written to:

- `figures/figure_duration_boxplots.svg`
- `figures/figure_memory_boxplots.svg`

## 7. Statistical Treatment
- Outlier handling: no trimming; whiskers show the full observed range per (handler, `per_page`).
- Central tendency comparisons: median emphasized over mean for skew resilience.
- Confidence intervals: not reported.

## 8. Results

This section reports empirical results from the deterministic pipeline (`RUNS=30` per (handler, `per_page`)). The canonical numeric tables (q1/median/q3) are generated from the exported long-format CSVs and recorded in:

- `data/results_summary.md`

Figures are generated from the same CSV inputs and written to:

- `figures/figure_duration_boxplots.svg`
- `figures/figure_memory_boxplots.svg`

### 8.1 Representative medians (q1/median/q3)

Duration (seconds):

- `per_page=1` (median): Go 0.000001; Ruby 0.000008; Node 0.000005; Python 0.000011
- `per_page=100000` (q1/median/q3):
	- Go 0.007082 / 0.007197 / 0.007402
	- Ruby 0.021580 / 0.021671 / 0.021867
	- Python 0.020327 / 0.021706 / 0.023912
	- Node 0.035766 / 0.036129 / 0.036431

Memory (bytes):

- `per_page=1` (median): Go 8,007,680; Node 65,105,920; Python 46,215,168; Ruby 125,116,416
- `per_page=100000` (median): Go 10,952,704; Node 123,707,392; Python 94,951,424; Ruby 170,205,184

Note: quartiles are computed from the sorted per-(task, handler) series using linear interpolation between adjacent sample points.

## 9. Discussion
Interpret comparative performance across workloads and page sizes. Highlight trade-offs:
- Implementation complexity vs throughput.
- Memory footprint variance.
- Ecosystem maturity and operational tooling.

## 10. Reproducibility
This repository is designed to be reproducible with Docker Compose, with a single canonical path that (a) seeds data deterministically, (b) runs a fixed benchmark schedule, and (c) exports CSVs and renders figures.

For archival publication, the repository is packaged as a single monorepo-style snapshot: `benchmark_ui/`, `golang_worker/`, `node_worker/`, and `python_worker/` are stored as ordinary directories in the artifact rather than as external submodules.

CSV export endpoints (if you prefer fetching via HTTP rather than using the tasks below):
- Per-task wide format: `/tasks/:id/durations_csv`, `/tasks/:id/memory_csv`
- Multi-task long format (selected tasks): `/durations/selected_csv`, `/memory/selected_csv`

### 10.1 Recommended: Docker Compose (canonical, end-to-end)

From `rails_8/`:

```bash
# Build images
docker compose build

# Start infra + workers + Rails UI + Sidekiq
docker compose up -d postgres redis
docker compose up -d benchmark_ui sidekiq
docker compose up -d golang_worker node_worker python_worker python_worker_api
```

Run the deterministic benchmark pipeline (seed + create tasks + enqueue runs) inside the Rails container:

```bash
docker compose run --rm benchmark_ui bash -lc '
ROWS=100000 SEED=123 DIST=survey \
PER_PAGES=1,10,25,50,100,250,500,1000,10000,100000 RUNS=30 PAGE=1 \
HANDLERS=ruby,go,python,node MODE=enqueue SCHEDULE=serial_by_handler WAIT=true \
bin/rails article:generate_all
'
```

After workers finish, export the canonical long-format CSVs and render the static figures:

```bash
docker compose run --rm benchmark_ui bash -lc 'bin/rails article:export_selected_csv'
docker compose run --rm benchmark_ui bash -lc 'bin/rails article:generate_figures'
```

Primary outputs (written under `benchmark_ui/docs/`):
- `data/durations_selected.csv`
- `data/memory_selected.csv`
- `data/results_summary.md`
- `figures/figure_duration_boxplots.svg`
- `figures/figure_memory_boxplots.svg`

Validated end-to-end run commit: `cc53fd63fb0cad0b4d6bb16fe474cb46fb00dd29`.

Teardown:

```bash
docker compose down -v
```

### 10.2 Optional: local Rails (non-Docker)

If you run Rails on the host instead of inside Compose, the minimum steps are:
- Ensure PostgreSQL and Redis are running (via Compose or locally).
- Seed deterministically:

	```bash
	ROWS=100000 SEED=123 DIST=survey bin/rails db:seed
	```

- Start Rails UI: `bin/rails server`.
- Enqueue benchmark runs from the UI or via API; run workers separately.
- Export CSVs and render figures: `bin/rails article:export_selected_csv` and `bin/rails article:generate_figures`.

### 10.3 Optional: run tests (Docker)

From `rails_8/`:

```bash
docker compose run --rm benchmark_ui bundle exec rspec
docker compose run --rm golang_worker_test
docker compose run --rm node_worker node --test
docker compose run --rm python_worker python -m unittest discover -s tests -p 'test_*.py'
```

### 10.4 Environment versions capture
- Record outputs of `ruby -v`, `bundle -v`, `node -v`, `go version`, `python --version`, `psql --version`, `redis-server --version`.
- Version pinning is captured in `Gemfile`, `go.mod`, `requirements.txt`, and `package.json`.

### 10.5 Notes on containerized services
- Compose defaults:
	- Postgres: `postgres:5432` database `benchmark_development` with `postgres/postgres`
	- Redis: `redis://redis:6379/0`
	- Rails runs in development mode in Compose to avoid requiring a master key.
- Python enqueue URL:
	- If Rails runs on the host, use `http://127.0.0.1:5001/enqueue` (host-published port).
	- If Rails runs in Compose, use `PYTHON_WORKER_URL=http://python_worker_api:5000/enqueue` (service DNS + container port).

## 11. Limitations & Threats to Validity
- Single-machine scope may not extrapolate to distributed clusters.
- Memory measurements approximate and runtime-dependent.
- Statistical significance contingent on repetition count.
- Absence of network latency factors.

## 12. Conclusion & Future Work
We supply a transparent multi-language benchmark harness enabling apples-to-apples comparisons for background computational tasks. Future directions: Rust implementation; distributed multi-node scaling; inclusion of JVM-based (e.g., Kotlin + Spring Batch) and Elixir (BEAM) ecosystems; power efficiency metrics.

## 13. References
1. Sidekiq. “Sidekiq” (README / project overview). https://github.com/sidekiq/sidekiq (accessed 2026-03-04).
2. Sidekiq Wiki. “Job Format”. https://github.com/sidekiq/sidekiq/wiki/Job-Format (accessed 2026-03-04).
3. Ruby on Rails Guides. “Active Job Basics”. https://guides.rubyonrails.org/active_job_basics.html (accessed 2026-03-04).
4. Celery Documentation. “Celery - Distributed Task Queue”. https://docs.celeryq.dev/en/stable/ (accessed 2026-03-04).
5. Flask Documentation. “Welcome to Flask”. https://flask.palletsprojects.com/ (accessed 2026-03-04).
6. Redis Documentation. “BRPOP”. https://redis.io/commands/brpop/ (accessed 2026-03-04).
7. Node.js Documentation. “The Node.js Event Loop”. https://nodejs.org/en/learn/asynchronous-work/event-loop-timers-and-nexttick (accessed 2026-03-04).
8. Python Documentation. “Glossary: global interpreter lock”. https://docs.python.org/3/glossary.html#term-global-interpreter-lock (accessed 2026-03-04).
9. Go Documentation. “Documentation” (entry point), and linked performance topics such as “A Guide to the Go Garbage Collector”. https://go.dev/doc/ (accessed 2026-03-04).
10. PostgreSQL Documentation. “PostgreSQL Documentation (current)”. https://www.postgresql.org/docs/current/ (accessed 2026-03-04).
11. Docker Documentation. “Docker Compose”. https://docs.docker.com/compose/ (accessed 2026-03-04).

---
*Repository artifact mapping:*
- Export services: `TaskSeriesCsvExporter`, `SelectedTasksMemoryCsvExporter`, `SelectedTasksDurationCsvExporter`.
- Request specs validate CSV endpoints.
- D3 visualization integrated in UI pages for memory and duration.
