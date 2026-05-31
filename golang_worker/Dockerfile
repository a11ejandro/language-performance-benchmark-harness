# syntax=docker/dockerfile:1

# --- Build stage ---
FROM golang:1.22-alpine@sha256:1699c10032ca2582ec89a24a1312d986a3f094aed3d5c1147b19880afe40e052 AS build
WORKDIR /app
# Install git for go modules fetching
RUN apk add --no-cache git

# Leverage caching by copying mod files first
COPY go.mod go.sum ./
RUN go mod download

# Copy sources
COPY . .

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$(go env GOARCH) go build -o /go_worker

# --- Final image ---
FROM alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc
WORKDIR /app
# Minimal runtime deps
RUN addgroup -S app && adduser -S app -G app
USER app

COPY --from=build /go_worker /usr/local/bin/go_worker

# Environment (override via compose)
ENV POSTGRES_HOST=postgres \
    POSTGRES_PORT=5432 \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    POSTGRES_DB=benchmark_development \
    REDIS_URL=redis://redis:6379/0 \
    WORKER_QUEUE=go \
    TZ=UTC

ENTRYPOINT ["/usr/local/bin/go_worker"]
CMD ["--service"]
