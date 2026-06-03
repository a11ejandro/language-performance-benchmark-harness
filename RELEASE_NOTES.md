# v1.0-paper

Archival artifact release for the paper:

_A Reproducible Runtime Performance Benchmark Across Ruby, Go, Python, and Node.js (via Background Job Execution)_

## Release identity

- release tag: `v1.0-paper`
- release branch tip at tagging time: `72cd7ce608a10d3f6f3ba51464da1469f87a6a18`

For this release, the archival tag and the validated benchmark-artifact snapshot are aligned to the same publish-candidate commit.

## What this release contains

This release publishes a single-repository benchmark artifact snapshot containing:

- the canonical orchestration entrypoint at `docker-compose.yml`
- the Rails benchmark UI in `benchmark_ui/`
- the Go worker in `golang_worker/`
- the Node worker in `node_worker/`
- the Python worker in `python_worker/`
- the paper source in `benchmark_ui/docs/article.md`
- generated benchmark artifacts under `benchmark_ui/docs/data/` and `benchmark_ui/docs/figures/`

This snapshot is intended to support citation, review, and third-party reproduction.

For this artifact, third-party reproduction means rebuilding the published benchmark environment, regenerating the seeded workload, and obtaining statistically comparable benchmark outputs. Because the benchmark measures live runtime and memory across long-running jobs on a real machine, reruns are not expected to reproduce byte-identical CSV, Markdown, or SVG files.

## Included benchmark artifacts

Generated files included in this release:

- `benchmark_ui/docs/data/durations_selected.csv`
- `benchmark_ui/docs/data/memory_selected.csv`
- `benchmark_ui/docs/data/results_summary.md`
- `benchmark_ui/docs/figures/figure_duration_boxplots.svg`
- `benchmark_ui/docs/figures/figure_memory_boxplots.svg`

Validated benchmark run record captured in `TODO_publish.md`:

- validated run commit: `72cd7ce608a10d3f6f3ba51464da1469f87a6a18`
- Sidekiq concurrency: `1`
- Celery concurrency: `1`
- Celery prefetch multiplier: `1`

That means the benchmark artifacts included in this release correspond to the same snapshot named by the release tag.

Those files are the archival outputs from one validated run of that snapshot. Later reruns should be compared by configuration parity and summary behavior, not by exact file hashes.

## Canonical reproduction path

From the repository root:

```bash
docker compose build

docker compose up -d postgres redis
docker compose run --rm benchmark_ui bin/rails db:prepare

docker compose up -d benchmark_ui sidekiq
docker compose up -d golang_worker node_worker python_worker python_worker_api

docker compose run --rm benchmark_ui bash -lc '
ROWS=100000 SEED=123 DIST=survey \
PER_PAGES=1,10,25,50,100,250,500,1000,10000,100000 RUNS=30 PAGE=1 \
HANDLERS=ruby,go,python,node MODE=enqueue SCHEDULE=serial_by_handler WAIT=true \
bin/rails article:generate_all
'
```

Expected outputs are written under `benchmark_ui/docs/`.

For a clean clone, the explicit `db:prepare` step is required before `article:generate_all`.

The seeded inputs and benchmark schedule are fixed; the measured runtime and memory series are expected to vary modestly across real reruns.

Rerun acceptance policy:
- Exact-match requirements:
	- same release tag or commit
	- same benchmark parameter set
	- same documented worker-concurrency settings
	- regeneration of the same canonical output file set
- Statistical-match requirements:
	- for `per_page >= 100`, each handler's duration median should remain within a `0.5x` to `2.0x` band of the archival run median
	- for `per_page >= 100`, each handler's memory median should remain within a `0.8x` to `1.25x` band of the archival run median
	- for `per_page = 1000`, `10000`, and `100000`, the qualitative ordering of handler medians should be preserved
	- no unexplained order-of-magnitude shift should appear in a handler's duration or memory profile
	- rerun reports should record the machine/environment used
- Non-goal:
	- exact rerun hash equality is not required for live benchmark outputs on a real machine

The smallest workloads (`per_page < 100`) are excluded from the numeric duration threshold because microsecond-scale timings are especially noisy.

Teardown:

```bash
docker compose down -v
```

## Release-relevant changes

This release includes publication-preparation changes needed to make the artifact self-describing and reproducible as a benchmark harness:

- canonical reproduction instructions in `README.md`
- citation metadata in `CITATION.cff`
- publication audit in `PUBLISH_AUDIT.md`
- publication checklist in `TODO_publish.md`
- reproducibility issue template in `.github/ISSUE_TEMPLATE/reproducibility.md`
- refreshed release-candidate metadata in `README.md` and `benchmark_ui/docs/article.md`

## Citation

Repository URL:

- https://github.com/a11ejandro/language-performance-benchmark-harness

Citation metadata is available in `CITATION.cff`.

## Known remaining publication tasks

This release snapshot does not itself provide:

- a Zenodo DOI
- a submission PDF for the paper
- a documented fresh-clone post-release validation record

Those may be added in follow-up publication steps without changing the benchmark methodology.