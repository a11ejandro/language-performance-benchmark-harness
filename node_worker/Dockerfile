# syntax=docker/dockerfile:1

FROM node:24-alpine
WORKDIR /app

# Install deps first for better caching
COPY package*.json ./
RUN npm ci --omit=dev || npm install --only=production

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
