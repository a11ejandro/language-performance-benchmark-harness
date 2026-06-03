# A Reproducible Runtime Performance Benchmark Across Ruby, Go, Python, and Node.js (via Background Job Execution) (artifact repository)

This repository contains a reproducible benchmark harness used for the accompanying paper.

In this repository, "reproducible" means the benchmark inputs, orchestration, and environment definition can be recreated from the published instructions. Because the benchmark measures live runtime and memory on a real machine across long-running jobs, reruns are expected to produce statistically comparable results rather than byte-identical CSV, Markdown, or SVG outputs.

- Paper (source): `benchmark_ui/docs/article.md`
- Generated artifacts (CSV + SVG): `benchmark_ui/docs/data/` and `benchmark_ui/docs/figures/`
- Canonical orchestration entrypoint: `docker-compose.yml` at repo root
- Archival layout: the benchmark UI and language workers are vendored as plain subdirectories in this repository; they are not separate submodules for publication.

## Reproduce (canonical)

From the repository root:

```bash
# Build images
docker compose build

# Start infra first
docker compose up -d postgres redis

# Prepare the database explicitly for a clean clone
docker compose run --rm benchmark_ui bin/rails db:prepare

# Start Rails UI + workers
docker compose up -d benchmark_ui sidekiq
docker compose up -d golang_worker node_worker python_worker python_worker_api

# Run the fixed benchmark pipeline inside the Rails container
docker compose run --rm benchmark_ui bash -lc '
ROWS=100000 SEED=123 DIST=survey \
PER_PAGES=1,10,25,50,100,250,500,1000,10000,100000 RUNS=30 PAGE=1 \
HANDLERS=ruby,go,python,node MODE=enqueue SCHEDULE=serial_by_handler WAIT=true \
bin/rails article:generate_all
'
```

Expected outputs (written under `benchmark_ui/docs/`):
- `data/durations_selected.csv`
- `data/memory_selected.csv`
- `data/results_summary.md`
- `figures/figure_duration_boxplots.svg`
- `figures/figure_memory_boxplots.svg`

The explicit `db:prepare` step is required for a clean clone because the benchmark command runs via `bash -lc ... bin/rails article:generate_all`, which does not trigger the image entrypoint's automatic database preparation.

The seeded dataset and task matrix are deterministic. The measured runtime and memory outputs are not expected to be byte-identical across reruns on a real machine; compare them statistically rather than by exact file hashes.

Rerun acceptance policy:
- Exact-match requirements:
	- the same benchmark commit or release tag is used
	- the same benchmark parameters are used (`ROWS`, `SEED`, `DIST`, `PER_PAGES`, `RUNS`, `PAGE`, `HANDLERS`, `MODE`, `SCHEDULE`, `WAIT`)
	- the same worker-concurrency constraints are used (Sidekiq concurrency `1`, Celery concurrency `1`, Celery prefetch multiplier `1`, one-job Go/Node loops)
	- the same canonical artifact files are regenerated under `benchmark_ui/docs/`
- Statistical-match requirements:
	- for `per_page >= 100`, each handler's duration median should remain within a `0.5x` to `2.0x` band of the archival run median — except Node.js at `per_page < 1000`, where the band is `0.25x` to `4.0x` due to its documented high scheduling variance at small workloads
	- for `per_page >= 100`, each handler's memory median should remain within a `0.8x` to `1.25x` band of the archival run median
	- for the largest workloads (`per_page = 1000`, `10000`, `100000`), the qualitative ordering of handler medians should be preserved — except that Ruby and Python are treated as an unordered pair, since their IQRs overlap at large workloads
	- no handler should shift by an order of magnitude at any workload without an explained environment or code change
	- any reported rerun should include the machine/environment description used for that run
- Non-goal:
	- exact SHA-256 equality of rerun CSV, Markdown, or SVG outputs is not required for live benchmark reruns on a real machine

The smallest workloads (`per_page < 100`) are excluded from the numeric duration threshold because microsecond-scale timings are especially sensitive to scheduler and timer noise.

Teardown:

```bash
docker compose down -v
```

Automated rerun reproducibility helpers:

```bash
# Save the current canonical outputs under benchmark_ui/tmp/repro_runs/<name>
docker compose run --rm benchmark_ui bin/rails "article:snapshot_rerun[run-1]"

# After another full rerun, compare the current outputs against that snapshot
docker compose run --rm benchmark_ui bin/rails "article:compare_rerun[tmp/repro_runs/run-1]"
```

## Run tests (no local installs)

```bash
# Rails / RSpec
docker compose run --rm benchmark_ui bundle exec rspec

# Go worker unit tests
docker compose run --rm golang_worker_test

# Node worker unit tests
docker compose run --rm node_worker node --test

# Python worker unit tests
docker compose run --rm python_worker python -m unittest discover -s tests -p 'test_*.py'
```

## How to cite

Repository URL: https://github.com/a11ejandro/language-performance-benchmark-harness

Published release: https://github.com/a11ejandro/language-performance-benchmark-harness/releases/tag/v1.0-paper

APA-style (software/repository):

Potrakhov, O. (2026). *A Reproducible Runtime Performance Benchmark Across Ruby, Go, Python, and Node.js (via Background Job Execution)* (Version v1.0-paper) [Computer software]. GitHub. https://github.com/a11ejandro/language-performance-benchmark-harness/releases/tag/v1.0-paper

BibTeX (software/repository):

```bibtex
@software{potrakhov_language_performance_benchmark_harness_2026,
	author  = {Oleksandr Potrakhov},
	title   = {A Reproducible Runtime Performance Benchmark Across Ruby, Go, Python, and Node.js (via Background Job Execution)},
	year    = {2026},
	version = {v1.0-paper},
	url     = {https://github.com/a11ejandro/language-performance-benchmark-harness/releases/tag/v1.0-paper}
}
```

If you publish an arXiv preprint, prefer citing the arXiv record and include the repository as the artifact link.

## Notes

- `benchmark_ui/docker-compose.yml` exists but is partial/legacy; it is not the canonical reproduction path.
- This artifact is published as a single archival repository. `benchmark_ui/`, `golang_worker/`, `node_worker/`, and `python_worker/` are included directly so one repository snapshot captures the full benchmark harness.
- Publication metadata: see `LICENSE` and `CITATION.cff` at repo root.
