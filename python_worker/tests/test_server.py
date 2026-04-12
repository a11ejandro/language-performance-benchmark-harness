import os
import unittest
from unittest import mock

from server import flask_app


class EnqueueApiTest(unittest.TestCase):
    def setUp(self):
        self.client = flask_app.test_client()

    def test_missing_test_run_id_returns_400(self):
        res = self.client.post("/enqueue", json={})
        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.get_json(), {"error": "test_run_id missing"})

    def test_invalid_test_run_id_returns_400(self):
        res = self.client.post("/enqueue", json={"test_run_id": "nope"})
        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.get_json(), {"error": "test_run_id must be an integer"})

    def test_valid_test_run_id_enqueues(self):
        fake_result = mock.Mock(id="abc123")

        with mock.patch.dict(os.environ, {}, clear=False):
            with mock.patch("server.celery_app.send_task", return_value=fake_result) as send_task:
                res = self.client.post("/enqueue", json={"test_run_id": 123})

        self.assertEqual(res.status_code, 202)
        self.assertEqual(res.get_json(), {"task_id": "abc123"})
        send_task.assert_called_once_with("PythonWorker", args=[123], queue="python")

    def test_queue_env_var_overrides_default(self):
        fake_result = mock.Mock(id="q1")

        with mock.patch.dict(os.environ, {"WORKER_QUEUE": "pyq"}, clear=False):
            with mock.patch("server.celery_app.send_task", return_value=fake_result) as send_task:
                res = self.client.post("/enqueue", json={"test_run_id": 7})

        self.assertEqual(res.status_code, 202)
        self.assertEqual(res.get_json(), {"task_id": "q1"})
        send_task.assert_called_once_with("PythonWorker", args=[7], queue="pyq")


if __name__ == "__main__":
    unittest.main()
