import unittest

from python_worker.stats import calculate


class CalculateStatisticsTest(unittest.TestCase):
    def test_even_sample(self):
        stats = calculate([40.0, 10.0, 30.0, 20.0])

        self.assertEqual(stats["min"], 10.0)
        self.assertEqual(stats["max"], 40.0)
        self.assertEqual(stats["mean"], 25.0)
        self.assertEqual(stats["median"], 25.0)
        self.assertEqual(stats["q1"], 10.0)
        self.assertEqual(stats["q3"], 30.0)
        self.assertAlmostEqual(stats["standard_deviation"], 11.180339887, places=9)

    def test_odd_sample(self):
        stats = calculate([3.0, 1.0, 2.0])

        self.assertEqual(stats["min"], 1.0)
        self.assertEqual(stats["max"], 3.0)
        self.assertEqual(stats["mean"], 2.0)
        self.assertEqual(stats["median"], 2.0)
        self.assertEqual(stats["q1"], 1.0)
        self.assertEqual(stats["q3"], 3.0)

    def test_empty_sample(self):
        stats = calculate([])

        self.assertTrue(all(value is None for value in stats.values()))

