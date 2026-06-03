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
    orcid: 0009-0008-5757-962X
    affiliation: 1
affiliations:
  - name: Independent Researcher
    index: 1
date: 2026-06-02
bibliography: paper.bib
---

# Summary

This software provides a reproducible multi-language benchmark harness for measuring the computational performance of background job workers implemented in Ruby (Rails/Sidekiq [@sidekiq]), Go, Python (Celery [@celery]), and Node.js. Workers consume jobs from a shared Redis queue [@redis-brpop], fetch a deterministic slice of survey data from a shared PostgreSQL database [@postgresql], compute descriptive statistics (min, max, mean, median, quartiles) using idiomatic but abstraction-minimal code, and record duration and peak-memory measurements back to the database. The harness orchestrates 30 repeated runs per (language, workload) pair across ten page sizes ranging from 1 to 100,000 rows, exports raw measurement series as CSV, renders box-plot visualizations, and enforces a machine-readable rerun acceptance policy that validates statistical reproducibility across independent benchmark runs on any compatible machine.

All workers share a single PostgreSQL schema, identical algorithmic logic, and the same Redis-based job queue. Ruby uses Sidekiq's native worker interface [@sidekiq-job-format]; the Go, Python, and Node.js workers are custom implementations of the Sidekiq wire protocol, consuming the same JSON job payloads over Redis `BRPOP` [@redis-brpop]. This shared infrastructure eliminates serialization and schema asymmetries as confounders, isolating computational throughput as the variable under study.

# Statement of Need

Engineering teams routinely evaluate multiple language runtimes when designing or migrating computational background job pipelines, yet rigorous cross-language comparisons are rare in the literature. Informal benchmarks frequently suffer from non-equivalent implementations (different algorithms, different data volumes, different persistence strategies), missing raw data (only summary statistics are published), and no reproducibility guarantee (no fixed seed, no pinned versions, no environment definition).

This software addresses that gap by providing:

1. **A single shared schema and identical algorithmic logic** across all four workers, minimizing implementation bias. Each worker fetches the same rows via the same SQL query and computes statistics with the same iterative approach — no high-level statistics libraries are used.
2. **Deterministic data generation** controlled by a seed and distribution parameter, enabling independent reruns to start from the same dataset regardless of machine.
3. **Raw series persistence** — all 30 per-run measurements are stored in the database and exported as CSV, not just summary statistics. This allows third parties to recompute any aggregate or apply alternative statistical methods.
4. **A formal rerun acceptance policy** implemented as a Ruby service that checks median ratio bounds and rank-ordering preservation across independent reruns, with per-runtime exceptions grounded in the documented variance characteristics of each runtime (e.g., Node.js event-loop scheduling jitter at sub-millisecond workloads [@nodejs-event-loop]).
5. **D3-based interactive visualizations** of distributional statistics embedded in the benchmark UI, and SVG exports for inclusion in publications.

The target audience is software engineers and researchers making runtime selection decisions for throughput-sensitive, CPU-bound background workloads, and reproducibility researchers who need a concrete multi-language harness to study or extend.

# Methods

The benchmark environment is defined entirely via Docker Compose [@docker-compose]: five services share one PostgreSQL instance and one Redis instance. Rails 8 / Sidekiq provides orchestration, storage, and export; the Go, Python/Celery [@celery], and Node.js workers each implement the same Sidekiq-compatible consumer loop. A small Flask [@flask] HTTP bridge adapts Rails' enqueue path to Celery's broker API. The Python worker is subject to CPython's Global Interpreter Lock [@python-gil], which limits parallelism; workers are configured for single-job-at-a-time execution across all runtimes to eliminate concurrency as a variable.

Memory is measured as peak OS-level RSS sampled at 10 ms intervals during job execution, using the same `/proc/self/statm` → `ps -o rss=` approach across all four runtimes. Duration measures the computation phase only — Redis dequeue, SQL fetch, and result write are excluded. Median and IQR are the primary summary statistics; IQR non-overlap between runtime pairs is used to assess ordering claims without formal significance testing.

# Findings

All results were collected on a single Apple M2 Pro under macOS in Docker containers. At `per_page=100,000` rows — the largest tested workload — Go's median duration is 7.87 ms, compared to 22.6 ms for Ruby, 23.8 ms for Python, and 58.2 ms for Node.js. The rank ordering Go < Ruby ≈ Python < Node.js is stable across all 30 runs at workloads of 1,000 rows and above: IQRs are non-overlapping for every pair except Ruby and Python at `per_page=100,000`, where their IQRs fully overlap, indicating statistical equivalence at that scale.

Go's memory footprint is approximately 14× lower than Ruby and 20× lower than Node.js at the largest workload, reflecting differences in runtime baseline overhead (Go's self-contained binary versus Ruby's MRI + Sidekiq threading layer and Node.js's V8 heap) rather than algorithmic allocation. Go's memory growth from `per_page=1` to `per_page=100,000` is 3.6 MB; Node.js's growth over the same range is 124 MB.

Node.js exhibits the widest IQR at intermediate workloads (250–1,000 rows), consistent with event-loop scheduling jitter [@nodejs-event-loop] at sub-millisecond computation times. At `per_page=100,000`, where computation dominates, Node.js's IQR narrows substantially.

These conclusions hold under the conditions of this benchmark: single-threaded workers, serial scheduling, a shared PostgreSQL backend, and purely in-memory statistical computation on a single machine. Results on different hardware, operating systems, or with I/O-bound workloads may differ.

# Acknowledgements

No funding was received for this work.

# References
