import unittest

from python_worker import db


class FakeCursor:
    def __init__(self, row=None, rows=None):
        self.executed = []
        self._row = row
        self._rows = rows or []

    def execute(self, query, params=None):
        self.executed.append((query, params))

    def fetchone(self):
        return self._row

    def fetchall(self):
        return self._rows


class DbHelpersTest(unittest.TestCase):
    def test_fetch_task_window_defaults(self):
        cursor = FakeCursor(row=None)

        page, per_page = db.fetch_task_window(cursor, 42)

        self.assertEqual(page, 1)
        self.assertEqual(per_page, 1)
        self.assertEqual(len(cursor.executed), 1)

    def test_fetch_task_window_reads_values(self):
        cursor = FakeCursor(row={"page": "3", "per_page": "25"})

        page, per_page = db.fetch_task_window(cursor, 99)

        self.assertEqual(page, 3)
        self.assertEqual(per_page, 25)

    def test_fetch_samples_enforces_window(self):
        rows = [{"value": 10.0}, {"value": 20.0}, {"value": None}]
        cursor = FakeCursor(rows=rows)

        values = db.fetch_samples(cursor, page=2, per_page=2)

        self.assertEqual(values, [10.0, 20.0])
        self.assertEqual(
            cursor.executed[0],
            ("SELECT value FROM samples ORDER BY id ASC LIMIT %s OFFSET %s", (2, 2)),
        )

    def test_safe_int_handles_bad_values(self):
        self.assertEqual(db._safe_int("5"), 5)
        self.assertEqual(db._safe_int(None, default=11), 11)
        self.assertEqual(db._safe_int("oops", default=7), 7)


if __name__ == "__main__":
    unittest.main()
