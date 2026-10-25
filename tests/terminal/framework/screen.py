from __future__ import annotations

from dataclasses import dataclass
import hashlib

import pyte


@dataclass(frozen=True)
class ScreenSnapshot:
    lines: tuple[str, ...]
    cursor_row: int
    cursor_column: int
    columns: int
    rows: int
    line_has_highlight: tuple[bool, ...] = ()

    @property
    def text(self) -> str:
        return "\n".join(self.lines)


class VirtualTerminalScreen:
    def __init__(self, columns: int, rows: int) -> None:
        self.columns = columns
        self.rows = rows
        self._screen = pyte.Screen(columns, rows)
        self._stream = pyte.Stream(self._screen)

    def feed(self, data: str) -> None:
        if data:
            self._stream.feed(data)

    def snapshot(self) -> ScreenSnapshot:
        line_list = tuple(line.rstrip() for line in self._screen.display)
        return ScreenSnapshot(
            lines=line_list,
            cursor_row=self._screen.cursor.y,
            cursor_column=self._screen.cursor.x,
            columns=self.columns,
            rows=self.rows,
            line_has_highlight=tuple(
                self._line_has_highlight(row_index)
                for row_index in range(self.rows)
            ),
        )

    def signature(self) -> str:
        snapshot = self.snapshot()
        payload = "\n".join(snapshot.lines) + f"\n@{snapshot.cursor_row}:{snapshot.cursor_column}"
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()

    def cursor_position_report(self) -> str:
        snapshot = self.snapshot()
        return f"\x1b[{snapshot.cursor_row + 1};{snapshot.cursor_column + 1}R"

    def _line_has_highlight(self, row_index: int) -> bool:
        for cell in self._screen.buffer[row_index].values():
            if getattr(cell, "reverse", False):
                return True

            if getattr(cell, "bg", "default") != "default":
                return True

        return False
