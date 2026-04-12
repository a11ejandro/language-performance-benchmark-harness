# syntax=docker/dockerfile:1

FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=UTC

WORKDIR /app

# System deps (none required for psycopg2-binary)
RUN pip install --no-cache-dir --upgrade pip

# Install Python deps first for caching
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY . .

# Default environment (override in compose)
ENV POSTGRES_HOST=postgres \
    POSTGRES_PORT=5432 \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    POSTGRES_DB=benchmark_development \
    REDIS_URL=redis://redis:6379/0 \
    WORKER_QUEUE=python \
    PYTHON_WORKER_HOST=0.0.0.0 \
    PYTHON_WORKER_PORT=5000

# By default, start a Celery worker. For the HTTP API, override the command in compose.
CMD ["bash", "-lc", "celery -A celery_app.app worker -Q ${WORKER_QUEUE:-python} -l info"]
