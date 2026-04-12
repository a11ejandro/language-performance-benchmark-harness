import threading
import time
import unittest
from unittest import mock

from python_worker import tasks


class TasksHelpersTest(unittest.TestCase):
    def test_calculate_with_timing(self):
        stats, duration = tasks._calculate_with_timing([1.0, 2.0, 3.0, 4.0])

        self.assertEqual(stats["mean"], 2.5)
        self.assertGreaterEqual(duration, 0.0)

    def test_measure_peak_resident_memory_tracks_peak(self):
        readings = [100.0, 120.0, 160.0, 140.0]
        lock = threading.Lock()

        def fake_rss():
            with lock:
                if readings:
                    return readings.pop(0)
                return 160.0

        def work():
            time.sleep(0.002)
            return ("ok", 0.0)

        with mock.patch("python_worker.tasks.rss_bytes", side_effect=fake_rss):
            with mock.patch("python_worker.tasks.SAMPLING_INTERVAL", 0.0001):
                result, peak = tasks.measure_peak_resident_memory(work)

        self.assertEqual(result, ("ok", 0.0))
        self.assertEqual(peak, 160.0)

    def test_measure_peak_resident_memory_handles_missing_values(self):
        with mock.patch("python_worker.tasks.rss_bytes", return_value=None):
            with mock.patch("python_worker.tasks.SAMPLING_INTERVAL", 0.0001):
                result, peak = tasks.measure_peak_resident_memory(lambda: "done")

        self.assertEqual(result, "done")
        self.assertEqual(peak, 0.0)


if __name__ == "__main__":
    unittest.main()
