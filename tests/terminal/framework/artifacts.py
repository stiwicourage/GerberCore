from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import shutil
from typing import Any

from .pty_session import InputEvent
from .screen import ScreenSnapshot


def _mask_text(text: str, sensitive_value_list: list[str]) -> str:
    masked = text
    for value in sorted((item for item in sensitive_value_list if item), key=len, reverse=True):
        masked = masked.replace(value, f"<redacted:{len(value)}>")
    return masked


@dataclass(frozen=True)
class RuntimePaths:
    run_root: Path
    scenario_root: Path
    clipboard_state_path: Path
    credential_state_path: Path
    http_fixture_path: Path
    http_state_path: Path
    module_state_path: Path
    diagnostic_state_path: Path
    prompt_trace_path: Path


@dataclass(frozen=True)
class FailureArtifacts:
    scenario_id: str
    scenario_title: str
    expected: str
    actual: str
    screen: ScreenSnapshot
    raw_output: str
    input_event_list: list[InputEvent]
    prompt_trace_text: str
    sensitive_value_list: list[str]
    failure_message: str
    python_traceback_text: str
    powershell_stack_trace_text: str
    reproduction_command: str
    module_state: dict[str, Any]
    harness_diagnostic_event_list: list[dict[str, Any]]
    session_diagnostic_event_list: list[dict[str, Any]]
    process_status: dict[str, Any]
    timeout_details: dict[str, Any] | None


def create_runtime_paths(run_root: Path, scenario_id: str) -> RuntimePaths:
    scenario_root = run_root / "runtime" / scenario_id
    scenario_root.mkdir(parents=True, exist_ok=True)
    return RuntimePaths(
        run_root=run_root,
        scenario_root=scenario_root,
        clipboard_state_path=scenario_root / "clipboard-state.json",
        credential_state_path=scenario_root / "credential-state.json",
        http_fixture_path=scenario_root / "http-fixture.json",
        http_state_path=scenario_root / "http-state.json",
        module_state_path=scenario_root / "module-state.json",
        diagnostic_state_path=scenario_root / "diagnostic-state.json",
        prompt_trace_path=scenario_root / "prompt-debug.log",
    )


def remove_runtime_artifacts(paths: RuntimePaths) -> None:
    if paths.scenario_root.exists():
        shutil.rmtree(paths.scenario_root)


def build_failure_event_payload(input_event_list: list[InputEvent]) -> list[dict[str, str | int]]:
    event_payload = []
    for event in input_event_list:
        if event.sensitive:
            event_payload.append({"kind": event.kind, "redactedLength": len(event.value)})
        else:
            event_payload.append({"kind": event.kind, "value": event.value})
    return event_payload


def _write_masked_text(path: Path, text: str, sensitive_value_list: list[str]) -> None:
    path.write_text(
        _mask_text(text, sensitive_value_list),
        encoding="utf-8",
    )


def write_failure_artifacts(*, paths: RuntimePaths, artifacts: FailureArtifacts) -> None:
    event_payload = build_failure_event_payload(artifacts.input_event_list)
    scenario_failure_root = paths.run_root / "failures" / artifacts.scenario_id
    scenario_failure_root.mkdir(parents=True, exist_ok=True)

    manifest = {
        "scenario": {
            "id": artifacts.scenario_id,
            "title": artifacts.scenario_title,
        },
        "expected": artifacts.expected,
        "actual": _mask_text(artifacts.actual, artifacts.sensitive_value_list),
        "renderedScreen": _mask_text(artifacts.screen.text, artifacts.sensitive_value_list),
        "failure": _mask_text(artifacts.failure_message, artifacts.sensitive_value_list),
        "reproductionCommand": artifacts.reproduction_command,
        "cursor": {"row": artifacts.screen.cursor_row, "column": artifacts.screen.cursor_column},
        "terminal": {"columns": artifacts.screen.columns, "rows": artifacts.screen.rows},
        "processStatus": artifacts.process_status,
        "timeoutDetails": artifacts.timeout_details,
        "moduleState": artifacts.module_state,
        "inputEvents": event_payload,
    }
    (scenario_failure_root / "failure.json").write_text(
        json.dumps(manifest, indent=2),
        encoding="utf-8",
    )
    _write_masked_text(
        scenario_failure_root / "screen.txt",
        artifacts.screen.text,
        artifacts.sensitive_value_list,
    )
    _write_masked_text(
        scenario_failure_root / "raw-output.txt",
        artifacts.raw_output,
        artifacts.sensitive_value_list,
    )
    _write_masked_text(
        scenario_failure_root / "prompt-trace.log",
        artifacts.prompt_trace_text,
        artifacts.sensitive_value_list,
    )
    _write_masked_text(
        scenario_failure_root / "traceback.txt",
        "\n\n".join(
            [
                "Python traceback:",
                artifacts.python_traceback_text,
                "PowerShell stack trace:",
                artifacts.powershell_stack_trace_text or "<not available>",
            ]
        ),
        artifacts.sensitive_value_list,
    )
    (scenario_failure_root / "module-state.json").write_text(
        json.dumps(artifacts.module_state, indent=2),
        encoding="utf-8",
    )
    (scenario_failure_root / "diagnostic-events.json").write_text(
        json.dumps(
            {
                "harnessEvents": artifacts.harness_diagnostic_event_list,
                "sessionEvents": artifacts.session_diagnostic_event_list,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
