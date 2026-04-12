# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Run tests (no local installs)

From the repository root (`rails_8/`):

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

## Docker Compose (reproducibility)

There are two Compose files in this workspace:

- `rails_8/docker-compose.yml` (canonical): full stack used for the paper (Postgres, Redis, Rails UI, Sidekiq, Go/Node/Python workers, and the Python enqueue API).
- `rails_8/benchmark_ui/docker-compose.yml` (partial/legacy): not sufficient to reproduce the end-to-end benchmark by itself.

For the paper’s reproducibility steps, run Compose from `rails_8/` (or pass `-f` explicitly):

```bash
# From rails_8/
docker compose up -d postgres redis benchmark_ui sidekiq golang_worker node_worker python_worker python_worker_api

# Or from rails_8/benchmark_ui/
docker compose -f ../docker-compose.yml up -d postgres redis benchmark_ui sidekiq golang_worker node_worker python_worker python_worker_api
```
