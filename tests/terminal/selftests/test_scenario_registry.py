from __future__ import annotations

from pathlib import Path
import sys
import unittest


TERMINAL_ROOT = Path(__file__).resolve().parents[1]
if str(TERMINAL_ROOT) not in sys.path:
    sys.path.insert(0, str(TERMINAL_ROOT))

from framework.scenario_registry import SCENARIO_REGISTRY, scenario


class ScenarioRegistryTests(unittest.TestCase):
    def test_rejects_duplicate_scenario_identifier(self) -> None:
        original_registry = list(SCENARIO_REGISTRY)
        SCENARIO_REGISTRY.clear()
        try:
            decorator = scenario("duplicate", title="Duplicate", categories=("core",))
            decorator(lambda _context: None)

            with self.assertRaisesRegex(ValueError, "Duplicate terminal scenario identifier"):
                decorator(lambda _context: None)
        finally:
            SCENARIO_REGISTRY[:] = original_registry


if __name__ == "__main__":
    unittest.main()
