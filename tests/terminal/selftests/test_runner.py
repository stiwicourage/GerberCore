from __future__ import annotations

import argparse
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


TERMINAL_ROOT = Path(__file__).resolve().parents[1]
if str(TERMINAL_ROOT) not in sys.path:
    sys.path.insert(0, str(TERMINAL_ROOT))

from framework.screen import ScreenSnapshot
import run_terminal_tests


class FakeApp:
    def __init__(self) -> None:
        self.runtime_paths = run_terminal_tests.create_runtime_paths(Path(tempfile.mkdtemp()) / "run", "sample-scenario")
        self.sensitive_value_list: list[str] = []
        self._assert_called = False
        self._closed = False

    def assert_no_unexpected_exception(self) -> None:
        self._assert_called = True
        raise AssertionError("Unexpected PowerShell exception detected in raw output: Cannot bind argument")

    def close(self) -> None:
        self._closed = True

    def snapshot(self) -> ScreenSnapshot:
        return ScreenSnapshot(lines=("❯ /help",), cursor_row=0, cursor_column=7, columns=120, rows=40)

    def raw_output(self) -> str:
        return "Cannot bind argument to parameter 'Text'."

    def input_event_list(self) -> list:
        return []

    def prompt_trace_text(self) -> str:
        return ""

    def module_state(self) -> dict:
        return {"validationStatus": "passed"}

    def harness_diagnostic_state(self) -> dict:
        return {"events": []}

    def session_diagnostic_event_list(self) -> list[dict]:
        return []

    def process_status(self) -> dict:
        return {"isAlive": False, "exitStatus": 1, "signalStatus": None}

    def timeout_details(self) -> dict:
        return {"kind": "wait-for", "description": "prompt"}


class FakeScenarioDefinition:
    id = "sample-scenario"
    title = "Sample scenario"
    categories = ("core",)
    viewport = (120, 40)

    @staticmethod
    def run(_context) -> None:
        return None


class RunnerBehaviorTests(unittest.TestCase):
    def test_extracts_stack_trace_from_prompt_trace(self) -> None:
        prompt_trace_text = (
            '{"Event":"menu-loop-exception","Data":'
            '{"ScriptStackTrace":"at Test-Command, test.ps1: line 4",'
            '"PositionMessage":"At test.ps1:4 char:1"}}'
        )

        result = run_terminal_tests.get_powershell_stack_trace({}, "raw output", prompt_trace_text)

        self.assertIn("at Test-Command", result)
        self.assertIn("At test.ps1", result)

    def test_prepare_run_root_uses_unique_per_run_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            args = argparse.Namespace(category="core", scenario_id=None)
            artifact_root = Path(temporary_directory)

            first_run_root, _ = run_terminal_tests.prepare_run_root(artifact_root, args)
            second_run_root, _ = run_terminal_tests.prepare_run_root(artifact_root, args)

        self.assertNotEqual(first_run_root, second_run_root)

    def test_run_scenario_fails_when_unexpected_exception_check_fails(self) -> None:
        fake_app = FakeApp()
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository_root = Path(temporary_directory)
            runner_context = run_terminal_tests.RunnerContext(
                args=argparse.Namespace(keep_success_artifacts=False, category=None, scenario_id=None),
                gerber_root=repository_root,
                artifact_root=repository_root / "artifacts/terminal",
                run_root=repository_root / "artifacts/terminal/runs/sample",
                failure_root=repository_root / "artifacts/terminal/runs/sample/failures",
            )

            with patch("run_terminal_tests.create_app", return_value=fake_app):
                result = run_terminal_tests.run_scenario(runner_context, FakeScenarioDefinition())

        self.assertEqual("failed", result.status)
        self.assertTrue(fake_app._assert_called)
        self.assertTrue(fake_app._closed)


if __name__ == "__main__":
    unittest.main()
