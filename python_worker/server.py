import os
from typing import Tuple

from dotenv import load_dotenv
from flask import Flask, jsonify, request

from celery_app import app as celery_app


load_dotenv(os.path.join(os.path.dirname(__file__), "..", "benchmark_ui", ".env"))
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))


flask_app = Flask(__name__)


@flask_app.post("/enqueue")
def enqueue() -> Tuple[str, int]:
    payload = request.get_json(silent=True) or {}
    if "test_run_id" not in payload:
        return jsonify({"error": "test_run_id missing"}), 400

    try:
        test_run_id = int(payload["test_run_id"])
    except (TypeError, ValueError):
        return jsonify({"error": "test_run_id must be an integer"}), 400

    queue = os.getenv("WORKER_QUEUE", "python")
    result = celery_app.send_task("PythonWorker", args=[test_run_id], queue=queue)
    return jsonify({"task_id": result.id}), 202


if __name__ == "__main__":
    flask_app.run(host=os.getenv("PYTHON_WORKER_HOST", "127.0.0.1"), port=int(os.getenv("PYTHON_WORKER_PORT", "5000")))

