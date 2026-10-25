from __future__ import annotations

from dataclasses import dataclass
import re
import time
from typing import Callable

import pexpect

from .screen import ScreenSnapshot, VirtualTerminalScreen


class ScreenTimeoutError(AssertionError):
    pass


KEY_MAP = {
    "ENTER": "\r",
    "ESCAPE": "\x1b",
    "SPACE": " ",
    "TAB": "\t",
    "BACKSPACE": "\x7f",
    "DELETE": "\x1b[3~",
    "HOME": "\x1b[H",
    "END": "\x1b[F",
    "LEFT": "\x1b[D",
    "RIGHT": "\x1b[C",
    "UP": "\x1b[A",
    "DOWN": "\x1b[B",
}
MAX_OUTPUT_CHUNKS_PER_PUMP = 64


@dataclass
class InputEvent:
    kind: str
    value: str
    sensitive: bool = False


@dataclass(frozen=True)
class SessionLaunchOptions:
    command: str
    arguments: list[str]
    environment: dict[str, str]
    columns: int
    rows: int
    timeout_seconds: float


class PtySession:
    def __init__(self, options: SessionLaunchOptions) -> None:
        self._terminal = VirtualTerminalScreen(options.columns, options.rows)
        self._child = pexpect.spawn(
            options.command,
            options.arguments,
            env=options.environment,
            encoding="utf-8",
            dimensions=(options.rows, options.columns),
            timeout=options.timeout_seconds,
        )
        self._input_event_list: list[InputEvent] = []
        self._raw_output_parts: list[str] = []
        self._pending_output = ""
        self._timeout_seconds = options.timeout_seconds
        self._diagnostic_event_list: list[dict[str, object]] = []
        self._last_timeout_details: dict[str, object] | None = None
        self._record_event(
            "spawn",
            command=options.command,
            arguments=list(options.arguments),
            columns=options.columns,
            rows=options.rows,
            timeoutSeconds=options.timeout_seconds,
        )

    @property
    def input_event_list(self) -> list[InputEvent]:
        return list(self._input_event_list)

    @property
    def raw_output(self) -> str:
        return "".join(self._raw_output_parts)

    @property
    def diagnostic_event_list(self) -> list[dict[str, object]]:
        return [dict(item) for item in self._diagnostic_event_list]

    @property
    def last_timeout_details(self) -> dict[str, object] | None:
        if self._last_timeout_details is None:
            return None
        return dict(self._last_timeout_details)

    def close(self) -> dict[str, object]:
        if self._child.isalive():
            self._child.close(force=True)
        status = self.process_status()
        self._record_event("close", **status)
        return status

    def send_text(self, value: str, *, sensitive: bool = False) -> None:
        if value:
            self._input_event_list.append(InputEvent(kind="text", value=value, sensitive=sensitive))
            event_payload = {"inputKind": "text", "length": len(value)}
            if not sensitive:
                event_payload["value"] = value
            self._record_event("send-input", **event_payload)
            self._child.send(value)

    def send_key(self, name: str) -> None:
        key_name = name.upper()
        if key_name not in KEY_MAP:
            raise KeyError(f"Unknown terminal key '{name}'.")

        self._input_event_list.append(InputEvent(kind="key", value=key_name))
        self._record_event("send-key", key=key_name)
        self._child.send(KEY_MAP[key_name])

    def snapshot(self) -> ScreenSnapshot:
        self._pump_output(quiet=True)
        return self._terminal.snapshot()

    def wait_for_stable_screen(
        self,
        *,
        timeout_seconds: float = 5.0,
        stable_for_seconds: float = 0.2,
    ) -> ScreenSnapshot:
        self._record_event(
            "wait-for-stable-screen-start",
            timeoutSeconds=timeout_seconds,
            stableForSeconds=stable_for_seconds,
        )
        deadline = time.monotonic() + timeout_seconds
        idle_cycle_count = 0
        minimum_idle_cycles = max(int(stable_for_seconds / 0.02), 2)
        while time.monotonic() < deadline:
            read_output = self._pump_output()
            if read_output:
                idle_cycle_count = 0
                time.sleep(0.02)
                continue
            idle_cycle_count += 1
            if idle_cycle_count >= minimum_idle_cycles:
                snapshot = self._terminal.snapshot()
                self._record_event(
                    "wait-for-stable-screen-success",
                    cursorRow=snapshot.cursor_row,
                    cursorColumn=snapshot.cursor_column,
                    signature=self._terminal.signature(),
                )
                return snapshot
            time.sleep(0.02)

        snapshot = self._terminal.snapshot()
        self._last_timeout_details = {
            "timeoutKind": "wait-for-stable-screen",
            "timeoutSeconds": timeout_seconds,
            "stableForSeconds": stable_for_seconds,
            "cursorRow": snapshot.cursor_row,
            "cursorColumn": snapshot.cursor_column,
            "screenSignature": self._terminal.signature(),
        }
        self._record_event("wait-for-stable-screen-timeout", **self._last_timeout_details)
        raise ScreenTimeoutError("The terminal screen did not stabilize before the timeout expired.")

    def wait_for(
        self,
        predicate: Callable[[ScreenSnapshot], bool],
        *,
        description: str,
        timeout_seconds: float = 5.0,
        stable_for_seconds: float = 0.2,
    ) -> ScreenSnapshot:
        self._record_event("wait-for-start", description=description, timeoutSeconds=timeout_seconds)
        deadline = time.monotonic() + timeout_seconds
        while time.monotonic() < deadline:
            try:
                snapshot = self.wait_for_stable_screen(
                    timeout_seconds=min(0.75, max(deadline - time.monotonic(), 0.1)),
                    stable_for_seconds=stable_for_seconds,
                )
            except ScreenTimeoutError:
                continue
            if predicate(snapshot):
                self._record_event(
                    "wait-for-success",
                    description=description,
                    cursorRow=snapshot.cursor_row,
                    cursorColumn=snapshot.cursor_column,
                )
                return snapshot
        self._last_timeout_details = {
            "timeoutKind": "wait-for",
            "description": description,
            "timeoutSeconds": timeout_seconds,
        }
        self._record_event("wait-for-timeout", **self._last_timeout_details)
        raise ScreenTimeoutError(f"Timed out while waiting for terminal state: {description}.")

    def wait_for_exit(self, *, timeout_seconds: float = 5.0) -> None:
        self._record_event("wait-for-exit-start", timeoutSeconds=timeout_seconds)
        deadline = time.monotonic() + timeout_seconds
        while time.monotonic() < deadline:
            self._pump_output(quiet=True)
            if not self._child.isalive():
                self._record_event("wait-for-exit-success", **self.process_status())
                return
            time.sleep(0.02)
        self._last_timeout_details = {
            "timeoutKind": "wait-for-exit",
            "timeoutSeconds": timeout_seconds,
        }
        self._record_event("wait-for-exit-timeout", **self._last_timeout_details)
        raise ScreenTimeoutError("Timed out while waiting for the PowerShell process to exit.")

    def process_status(self) -> dict[str, object]:
        return {
            "isAlive": self._child.isalive(),
            "exitStatus": self._child.exitstatus,
            "signalStatus": self._child.signalstatus,
        }

    def _pump_output(self, *, quiet: bool = False) -> bool:
        read_output = False
        for _ in range(MAX_OUTPUT_CHUNKS_PER_PUMP):
            try:
                data = self._child.read_nonblocking(size=4096, timeout=0)
            except pexpect.TIMEOUT:
                return read_output
            except pexpect.EOF:
                return read_output

            if not data:
                return read_output
            read_output = True
            self._consume_output(data, quiet=quiet)
        self._record_event(
            "output-pump-yield",
            chunkLimit=MAX_OUTPUT_CHUNKS_PER_PUMP,
        )
        return read_output

    def _consume_output(self, data: str, *, quiet: bool) -> None:
        text = self._pending_output + data
        self._pending_output = ""
        while text:
            match = re.search(r"\x1b\[\??6n", text)
            if match is None:
                break

            prefix = text[: match.start()]
            sequence = match.group(0)
            suffix = text[match.end() :]
            self._append_output(prefix, quiet=quiet)
            self._append_output(sequence, quiet=quiet)
            self._record_event("cursor-position-report-request")
            self._child.send(self._terminal.cursor_position_report())
            text = suffix

        if self._is_incomplete_cursor_report_request(text):
            self._pending_output = text
            return

        self._append_output(text, quiet=quiet)

    def _is_incomplete_cursor_report_request(self, text: str) -> bool:
        incomplete_suffix_list = ("\x1b", "\x1b[", "\x1b[6", "\x1b[?6")
        return any(text.endswith(suffix) for suffix in incomplete_suffix_list)

    def _append_output(self, value: str, *, quiet: bool) -> None:
        if not value:
            return
        self._raw_output_parts.append(value)
        self._terminal.feed(value)

    def _record_event(self, kind: str, **data: object) -> None:
        self._diagnostic_event_list.append(
            {
                "kind": kind,
                "timestamp": time.time(),
                **data,
            }
        )
