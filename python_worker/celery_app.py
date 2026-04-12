import os
from dotenv import load_dotenv
from celery import Celery
from kombu import Queue

# Load env from Rails app and local folder for convenience
load_dotenv(os.path.join(os.path.dirname(__file__), "..", "benchmark_ui", ".env"))
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

broker_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")

# Expose the Celery app instance as `app` for CLI discovery
app = Celery("python_worker", broker=broker_url, backend=broker_url, include=["python_worker.tasks"]) 

# Queue naming (keep separate from Sidekiq default unless intentionally shared)
default_queue = os.getenv("WORKER_QUEUE", "python")
app.conf.task_default_queue = default_queue
app.conf.task_queues = [
    Queue(default_queue),
]

# Reasonable defaults
app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone=os.getenv("TZ", "UTC"),
    enable_utc=True,
)
