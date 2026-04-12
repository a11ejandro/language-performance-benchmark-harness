import os
import sys
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", "benchmark_ui", ".env"))
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

from celery_app import app


def main():
    if len(sys.argv) < 2:
        print("usage: python enqueue.py <test_run_id>")
        sys.exit(2)
    test_run_id = int(sys.argv[1])
    q = os.getenv("WORKER_QUEUE", "python")
    r = app.send_task("PythonWorker", args=[test_run_id], queue=q)
    print(r.id)


if __name__ == "__main__":
    main()

