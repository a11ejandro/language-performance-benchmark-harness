# A Reproducible Runtime Performance Benchmark Across Ruby, Go, Python, and Node.js (via Background Job Execution) (artifact repository)

This repository contains a reproducible benchmark harness used for the accompanying paper.

- Paper (source): `benchmark_ui/docs/article.md`
- Generated artifacts (CSV + SVG): `benchmark_ui/docs/data/` and `benchmark_ui/docs/figures/`
- Canonical orchestration entrypoint: `docker-compose.yml` at repo root
- Archival layout: the benchmark UI and language workers are vendored as plain subdirectories in this repository; they are not separate submodules for publication.

## Reproduce (canonical)

From the repository root:

```bash
# Build images
docker compose build

# Start infra + workers + Rails UI + Sidekiq
docker compose up -d postgres redis
docker compose up -d benchmark_ui sidekiq
docker compose up -d golang_worker node_worker python_worker python_worker_api

# Run deterministic pipeline inside the Rails container
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

Teardown:

```bash
docker compose down -v
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

APA-style (software/repository):

Potrakhov, O. (2026). *A Reproducible Runtime Performance Benchmark Across Ruby, Go, Python, and Node.js (via Background Job Execution)* (Version cc53fd63) [Computer software]. GitHub. https://github.com/a11ejandro/language-performance-benchmark-harness

BibTeX (software/repository):

```bibtex
@software{potrakhov_language_performance_benchmark_harness_2026,
	author  = {Oleksandr Potrakhov},
	title   = {A Reproducible Runtime Performance Benchmark Across Ruby, Go, Python, and Node.js (via Background Job Execution)},
	year    = {2026},
	version = {cc53fd63},
	url     = {https://github.com/a11ejandro/language-performance-benchmark-harness}
}
```

If you publish an arXiv preprint, prefer citing the arXiv record and include the repository as the artifact link.

## Notes

- `benchmark_ui/docker-compose.yml` exists but is partial/legacy; it is not the canonical reproduction path.
- This artifact is published as a single archival repository. `benchmark_ui/`, `golang_worker/`, `node_worker/`, and `python_worker/` are included directly so one repository snapshot captures the full benchmark harness.
- Publication metadata: see `LICENSE` and `CITATION.cff` at repo root.
