from __future__ import annotations

from pathlib import Path
import sys
import unittest


TERMINAL_ROOT = Path(__file__).resolve().parents[1]
if str(TERMINAL_ROOT) not in sys.path:
    sys.path.insert(0, str(TERMINAL_ROOT))

from framework.pty_session import MAX_OUTPUT_CHUNKS_PER_PUMP, PtySession


class FakeChild:
    def __init__(self) -> None:
        self.call_count = 0

    def read_nonblocking(self, *, size: int, timeout: int) -> str:
        self.call_count += 1
        return "x"


class FakeTerminal:
    def feed(self, _value: str) -> None:
        return None


class PtySessionTests(unittest.TestCase):
    def test_output_pump_yields_after_bounded_chunk_count(self) -> None:
        session = PtySession.__new__(PtySession)
        session._child = FakeChild()
        session._terminal = FakeTerminal()
        session._pending_output = ""
        session._raw_output_parts = []
        session._diagnostic_event_list = []

        read_output = session._pump_output()

        self.assertTrue(read_output)
        self.assertEqual(MAX_OUTPUT_CHUNKS_PER_PUMP, session._child.call_count)
        self.assertEqual("output-pump-yield", session._diagnostic_event_list[-1]["kind"])


if __name__ == "__main__":
    unittest.main()
