from __future__ import annotations

from pathlib import Path
import json
import sys
import tempfile
import unittest


TERMINAL_ROOT = Path(__file__).resolve().parents[1]
if str(TERMINAL_ROOT) not in sys.path:
    sys.path.insert(0, str(TERMINAL_ROOT))

from framework.artifacts import FailureArtifacts, create_runtime_paths, write_failure_artifacts
from framework.pty_session import InputEvent
from framework.screen import ScreenSnapshot


class FailureArtifactTests(unittest.TestCase):
    def test_writes_required_failure_diagnostics(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            run_root = Path(temporary_directory) / "run"
            runtime_paths = create_runtime_paths(run_root, "sample-scenario")
            write_failure_artifacts(
                paths=runtime_paths,
                artifacts=FailureArtifacts(
                    scenario_id="sample-scenario",
                    scenario_title="Sample scenario",
                    expected="Expected outcome",
                    actual="Actual outcome",
                    screen=ScreenSnapshot(
                        lines=("❯ /help", "Preview: Show the built-in command help"),
                        cursor_row=0,
                        cursor_column=7,
                        columns=120,
                        rows=40,
                    ),
                    raw_output="Cannot bind argument to parameter 'Text'.",
                    input_event_list=[InputEvent(kind="text", value="/help", sensitive=False)],
                    prompt_trace_text="trace entry",
                    sensitive_value_list=[],
                    failure_message="Scenario failed.",
                    python_traceback_text="python traceback",
                    powershell_stack_trace_text="powershell stack trace",
                    reproduction_command="pwsh -File ./scripts/build/Invoke-TerminalRegressionCI.ps1 -ScenarioId sample-scenario",
                    module_state={"validationStatus": "passed"},
                    harness_diagnostic_event_list=[{"kind": "module-validation-complete"}],
                    session_diagnostic_event_list=[{"kind": "wait-for-timeout"}],
                    process_status={"isAlive": False, "exitStatus": 1, "signalStatus": None},
                    timeout_details={"timeoutKind": "wait-for", "description": "prompt"},
                ),
            )

            failure_root = run_root / "failures" / "sample-scenario"
            manifest = json.loads((failure_root / "failure.json").read_text(encoding="utf-8"))
            diagnostic_payload = json.loads((failure_root / "diagnostic-events.json").read_text(encoding="utf-8"))

            self.assertEqual("sample-scenario", manifest["scenario"]["id"])
            self.assertEqual("pwsh -File ./scripts/build/Invoke-TerminalRegressionCI.ps1 -ScenarioId sample-scenario", manifest["reproductionCommand"])
            self.assertEqual("passed", manifest["moduleState"]["validationStatus"])
            self.assertEqual("wait-for", manifest["timeoutDetails"]["timeoutKind"])
            self.assertTrue((failure_root / "traceback.txt").exists())
            self.assertTrue((failure_root / "module-state.json").exists())
            self.assertEqual("module-validation-complete", diagnostic_payload["harnessEvents"][0]["kind"])


if __name__ == "__main__":
    unittest.main()
