---
title: 'A Reproducible Runtime Performance Benchmark Across Ruby, Go, Python, and Node.js via Background Job Execution'
tags:
  - benchmark
  - runtime performance
  - background jobs
  - ruby
  - go
  - python
  - nodejs
  - reproducibility
authors:
  - name: Oleksandr Potrakhov
    orcid: 0000-0000-0000-0000
    affiliation: 1
affiliations:
  - name: Independent Researcher
    index: 1
date: 2026-06-02
bibliography: paper.bib
---

# Summary

This software provides a reproducible multi-language benchmark harness for measuring the computational performance of background job workers implemented in Ruby (Rails/Sidekiq), Go, Python (Celery), and Node.js. Workers consume jobs from a shared Redis queue, fetch a deterministic slice of survey data from PostgreSQL, compute descriptive statistics (min, max, mean, median, quartiles) using idiomatic but abstraction-minimal code, and record duration and memory measurements back to the database. The harness orchestrates 30 repeated runs per (language, workload) pair across ten page sizes ranging from 1 to 100,000 rows, exports raw results as CSV, renders box-plot visualizations, and enforces a machine-readable rerun acceptance policy that validates statistical reproducibility across independent benchmark runs.

# Statement of Need

Engineering teams routinely evaluate multiple language runtimes when designing or migrating computational background job pipelines, yet fair cross-language comparisons are rare in the literature. Informal benchmarks frequently suffer from non-equivalent implementations, missing raw data, and no reproducibility guarantee. This software addresses that gap by providing:

1. **A single shared schema and identical algorithmic logic** across all four workers, minimizing implementation bias.
2. **Deterministic data generation** controlled by seed and distribution parameters, enabling independent reruns to start from the same dataset.
3. **Raw series persistence** — all 30 per-run measurements are stored in the database and exported as CSV, not just summary statistics.
4. **A formal rerun acceptance policy** implemented as a Ruby service (`RerunReproducibility::Comparison`) that checks ratio bounds and rank-ordering preservation across independent reruns, with per-runtime exceptions grounded in the documented variance characteristics of each runtime.
5. **D3-based interactive visualizations** of distributional statistics embedded in the benchmark UI.

The target audience is software engineers and researchers making runtime selection decisions for throughput-sensitive, CPU-bound background workloads.

# Key Findings

At `per_page=100,000` rows — the largest tested workload — Go's median duration is 7.87 ms, compared to 22.6 ms for Ruby, 23.8 ms for Python, and 58.2 ms for Node.js. The rank ordering Go < Ruby ≈ Python < Node.js is stable across all 30 runs at workloads of 1,000 rows and above, with non-overlapping interquartile ranges between every pair except Ruby and Python (whose IQRs overlap at large workloads, indicating statistical equivalence). Go's memory footprint is approximately 14× lower than Ruby and 20× lower than Node.js at the largest workload, reflecting differences in runtime baseline overhead rather than algorithmic allocation. Node.js exhibits the widest IQR at intermediate workloads (250–1,000 rows), consistent with event-loop scheduling jitter at sub-millisecond computation times.

# Implementation

The harness runs entirely via Docker Compose. Five services are defined: a Rails 8 / PostgreSQL benchmark UI (orchestration, storage, export, visualization), a Sidekiq worker (Ruby), a Go worker, a Celery worker (Python), and a Node.js worker. All workers share one PostgreSQL database and one Redis instance. A single `docker compose run` invocation seeds 100,000 rows, runs the full benchmark schedule, and writes CSV and SVG artifacts to `benchmark_ui/docs/`. Rerun comparison is exposed both as a Rake task (`article:compare_rerun`) and as a persistent database-backed UI at `/comparison_runs`.

# Acknowledgements

No funding was received for this work.

# References
