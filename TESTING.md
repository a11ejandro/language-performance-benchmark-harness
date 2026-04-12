# Running Tests in Containers

This repo is set up so you can run tests without installing Go/Node/Python/Ruby locally.

All commands below assume you run them from the `rails_8/` directory.

## Build images

```bash
docker compose build
```

## Rails (benchmark_ui) specs

```bash
docker compose run --rm benchmark_ui bundle exec rspec
```

## Node worker tests

```bash
docker compose run --rm node_worker node --test
```

## Python worker tests

```bash
docker compose run --rm python_worker python -m unittest discover -s tests -p 'test_*.py'
```

## Go worker tests

The `golang_worker` runtime image is a minimal binary image and does not include the Go toolchain.
Run Go tests using the official Go image:

```bash
docker run --rm -v "$PWD/golang_worker:/app" -w /app golang:1.22-alpine sh -lc "apk add --no-cache git && go test ./..."
```
