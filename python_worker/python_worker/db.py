import os
from typing import List, Tuple, Optional

import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

# Load env like in celery_app
load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", "benchmark_ui", ".env"))
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))


def _dsn_from_env() -> str:
    url = os.getenv("DATABASE_URL")
    if url:
        return url
    host = os.getenv("POSTGRES_HOST", "localhost")
    port = os.getenv("POSTGRES_PORT", "5432")
    user = os.getenv("POSTGRES_USER", "postgres")
    password = os.getenv("POSTGRES_PASSWORD", "")
    dbname = os.getenv("POSTGRES_DB", "benchmark_development")
    return f"host={host} port={port} user={user} password={password} dbname={dbname} sslmode=disable"


def get_conn():
    return psycopg2.connect(_dsn_from_env(), cursor_factory=RealDictCursor)


def test_run_exists(cur, test_run_id: int) -> bool:
    cur.execute("SELECT 1 FROM test_runs WHERE id = %s", (test_run_id,))
    return cur.fetchone() is not None


def fetch_task_window(cur, test_run_id: int) -> Tuple[int, int]:
    query = """
        SELECT tasks.page, tasks.per_page
        FROM tasks
        INNER JOIN handlers ON handlers.task_id = tasks.id
        INNER JOIN test_runs ON test_runs.handler_id = handlers.id
        WHERE test_runs.id = %s
        LIMIT 1
    """
    cur.execute(query, (test_run_id,))
    row = cur.fetchone() or {}
    page = _safe_int(row.get("page"), default=1)
    per_page = max(_safe_int(row.get("per_page"), default=1), 1)
    return page, per_page


def fetch_samples(cur, page: int, per_page: int) -> List[float]:
    per_page = max(int(per_page), 1)
    page_index = max(int(page) - 1, 0)
    offset = per_page * page_index

    cur.execute(
        "SELECT value FROM samples ORDER BY id ASC LIMIT %s OFFSET %s",
        (per_page, offset),
    )
    rows = cur.fetchall()
    return [float(r["value"]) for r in rows if r["value"] is not None]


def insert_result(cur, test_run_id: int, stats: dict, duration: float, memory: float):
    q = (
        "INSERT INTO test_results (test_run_id, mean, median, q1, q3, min, max, standard_deviation, duration, memory, created_at, updated_at) "
        "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,NOW(),NOW())"
    )
    cur.execute(
        q,
        (
            test_run_id,
            stats.get("mean"),
            stats.get("median"),
            stats.get("q1"),
            stats.get("q3"),
            stats.get("min"),
            stats.get("max"),
            stats.get("standard_deviation"),
            duration,
            memory,
        ),
    )


def _safe_int(value: Optional[object], default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default
