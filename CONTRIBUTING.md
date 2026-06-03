# Contributing

Thank you for your interest in this project.

## Reporting issues

Use GitHub Issues to report bugs, unexpected benchmark results, or environment compatibility problems. Please include:
- Your OS, Docker version, and hardware (CPU, RAM)
- The exact `docker compose` commands you ran
- Relevant log output or error messages

## Suggesting improvements

Open an issue before submitting a pull request for significant changes (new worker implementations, schema changes, new metrics). For typos, documentation fixes, or minor test additions, a PR without a prior issue is fine.

## Adding a new language worker

A new worker must:

1. Consume Sidekiq-format JSON jobs from Redis (`BRPOP` on the handler's queue)
2. Fetch the specified `per_page` rows from the shared PostgreSQL `samples` table
3. Compute min, max, mean, median, q1, q3 using plain iterative code (no high-level stats library)
4. Write results back to the `test_results` table using the shared schema
5. Measure peak RSS at 10 ms intervals during job execution (same approach as existing workers — see `golang_worker/memory.go` for reference)
6. Be defined as a Docker Compose service in `docker-compose.yml`

## Running tests

```bash
docker compose build benchmark_ui
docker compose run --rm -e RAILS_ENV=test benchmark_ui bundle exec rspec
```

All specs must pass before a PR is merged.

## Code style

- Ruby: follow the existing style (no Rubocop config is enforced, but keep consistent with surrounding code)
- Go / Python / Node: follow the conventions already present in each worker
- Do not add linting or formatting tools unless discussed in an issue first

## Commit messages

Write short, lowercase imperative sentences. Example: `add rust worker skeleton`.
