# syntax=docker/dockerfile:1

FROM node:24-alpine@sha256:d1b3b4da11eefd5941e7f0b9cf17783fc99d9c6fc34884a665f40a06dbdfc94f
WORKDIR /app

# Install deps first for better caching
COPY package*.json ./
RUN npm ci --omit=dev

# Copy sources
COPY . .
ENV NODE_ENV=production \
    POSTGRES_HOST=postgres \
    POSTGRES_PORT=5432 \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    POSTGRES_DB=benchmark_development \
    REDIS_URL=redis://redis:6379/0 \
    WORKER_QUEUE=default \
    TZ=UTC

CMD ["node", "worker.js", "--service"]
