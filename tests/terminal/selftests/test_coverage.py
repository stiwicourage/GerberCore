from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace


TERMINAL_ROOT = Path(__file__).resolve().parents[1]
if str(TERMINAL_ROOT) not in sys.path:
    sys.path.insert(0, str(TERMINAL_ROOT))

from framework.coverage import build_coverage_report, load_exclusion_list
from framework.scenario_registry import ScenarioDefinition


def sample_scenario() -> ScenarioDefinition:
    return ScenarioDefinition(
        id="sample",
        title="Sample",
        categories=("core",),
        commands=("sample",),
        workflows=("command:sample",),
        coverage=("discovery", "dispatch"),
        viewport=(120, 40),
        run=lambda _context: None,
    )


class CoverageReportTests(unittest.TestCase):
    def test_requires_executable_coverage_for_each_category(self) -> None:
        report = build_coverage_report(
            inventory=[{"canonicalPath": "sample", "ownerName": "Core"}],
            scenario_list=[sample_scenario()],
            result_list=[SimpleNamespace(id="sample", status="passed")],
            exclusion_list=[],
        )

        self.assertEqual(4, len(report["issues"]))
        self.assertEqual("uncovered", report["commands"][0]["coverageStatus"])

    def test_expands_explicit_category_exclusions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "exclusions.json"
            path.write_text(
                """[
  {
    "command": "sample",
    "categories": ["workflow", "navigation", "rendering", "error-recovery"],
    "classification": "sample",
    "reason": "Explicit test classification."
  }
]""",
                encoding="utf-8",
            )
            exclusion_list = load_exclusion_list(path)

        report = build_coverage_report(
            inventory=[{"canonicalPath": "sample", "ownerName": "Core"}],
            scenario_list=[sample_scenario()],
            result_list=[SimpleNamespace(id="sample", status="passed")],
            exclusion_list=exclusion_list,
        )

        self.assertEqual([], report["issues"])
        self.assertEqual("excluded", report["commands"][0]["coverageStatus"])

    def test_reports_scenario_that_did_not_execute(self) -> None:
        report = build_coverage_report(
            inventory=[{"canonicalPath": "sample", "ownerName": "Core"}],
            scenario_list=[sample_scenario()],
            result_list=[],
            exclusion_list=[
                {
                    "command": "sample",
                    "category": category,
                    "classification": "sample",
                    "reason": "Explicit test classification.",
                }
                for category in ("workflow", "navigation", "rendering", "error-recovery")
            ],
        )

        issue_kind_list = [item["kind"] for item in report["issues"]]
        self.assertEqual(2, issue_kind_list.count("scenario-not-passed"))
        self.assertEqual("uncovered", report["commands"][0]["coverageStatus"])

    def test_reports_stale_exclusion(self) -> None:
        report = build_coverage_report(
            inventory=[{"canonicalPath": "sample", "ownerName": "Core"}],
            scenario_list=[sample_scenario()],
            result_list=[SimpleNamespace(id="sample", status="passed")],
            exclusion_list=[
                {
                    "command": "removed-command",
                    "category": "workflow",
                    "classification": "sample",
                    "reason": "Explicit test classification.",
                }
            ],
        )

        issue_kind_list = [item["kind"] for item in report["issues"]]
        self.assertIn("stale-exclusion", issue_kind_list)


if __name__ == "__main__":
    unittest.main()
