import os
import threading
import time
import ctypes
import ctypes.util
from contextlib import suppress

from celery import shared_task

from . import db
from .stats import calculate


@shared_task(name="PythonWorker")
def process_test_run(test_run_id: int):
    """Compute statistics for all samples and store a test_result row.

    Mirrors RubyWorker logic using plain SQL.
    """

    print(f"Processing test_run {test_run_id}")
    with db.get_conn() as conn:
        with conn.cursor() as cur:
            if not db.test_run_exists(cur, int(test_run_id)):
                return f"test_run {test_run_id} not found"

            page, per_page = db.fetch_task_window(cur, int(test_run_id))
            values = db.fetch_samples(cur, page, per_page)

            (stats, duration), peak = measure_peak_resident_memory(
                lambda: _calculate_with_timing(values)
            )

            db.insert_result(cur, int(test_run_id), stats, duration, float(peak))
    return f"ok:{test_run_id}"


SAMPLING_INTERVAL = 0.01


def _calculate_with_timing(values):
    start = time.perf_counter()
    stats = calculate(values)
    return stats, time.perf_counter() - start


def measure_peak_resident_memory(fn):
    baseline = rss_bytes()
    peak = baseline or 0
    running = True

    def sampler():
        nonlocal peak, running
        while running:
            current = rss_bytes()
            if current is None:
                time.sleep(SAMPLING_INTERVAL)
                continue
            if current > peak:
                peak = current
            time.sleep(SAMPLING_INTERVAL)

    thread = threading.Thread(target=sampler, name="rss-sampler", daemon=True)
    thread.start()
    try:
        result = fn()
    finally:
        running = False
        thread.join()
    peak_value = peak if peak is not None else baseline
    return result, float(peak_value or 0.0)


def rss_bytes():
    platform = sys_platform()
    if os.name == "posix":
        if platform.startswith("linux"):
            return rss_bytes_linux()
        if platform.startswith("darwin"):
            value = rss_bytes_darwin()
            if value is not None:
                return value
    return rss_bytes_via_ps()


def sys_platform():
    # Late import to avoid unnecessary costs when Celery distributes the module
    global _PLATFORM_CACHE
    if _PLATFORM_CACHE is None:
        import platform

        _PLATFORM_CACHE = platform.system().lower()
    return _PLATFORM_CACHE


_PLATFORM_CACHE = None


def rss_bytes_linux():
    with open(f"/proc/{os.getpid()}/statm", "r", encoding="utf-8") as statm:
        parts = statm.readline().split()
    if len(parts) < 2:
        return None
    pages = int(parts[1])
    return pages * os.sysconf("SC_PAGE_SIZE")


PROC_PIDTASKINFO = 4
PROC_TASKINFO_SIZE = 64
_LIBPROC = None


def rss_bytes_darwin():
    global _LIBPROC
    if _LIBPROC is None:
        libproc_path = ctypes.util.find_library("proc")
        if not libproc_path:
            return None
        with suppress(OSError):
            _LIBPROC = ctypes.cdll.LoadLibrary(libproc_path)
    if _LIBPROC is None:
        return None

    buffer = ctypes.create_string_buffer(PROC_TASKINFO_SIZE)
    ret = _LIBPROC.proc_pidinfo(
        os.getpid(),
        PROC_PIDTASKINFO,
        0,
        buffer,
        PROC_TASKINFO_SIZE,
    )
    if ret <= 0:
        return None
    # resident size is bytes 8-15
    resident_bytes = ctypes.c_uint64.from_buffer_copy(buffer.raw[8:16]).value
    return int(resident_bytes)


def rss_bytes_via_ps():
    with suppress(Exception):
        import subprocess

        output = subprocess.check_output(
            ["ps", "-o", "rss=", "-p", str(os.getpid())],
            text=True,
        ).strip()
        if output:
            return int(output) * 1024
    return None
