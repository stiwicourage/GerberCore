from __future__ import annotations

from dataclasses import asdict, dataclass
import json
from pathlib import Path
import subprocess
from typing import Iterable

from .scenario_registry import ScenarioDefinition


COVERAGE_CATEGORY_LIST = (
    "discovery",
    "dispatch",
    "workflow",
    "navigation",
    "rendering",
    "error-recovery",
)


@dataclass(frozen=True)
class CoverageIssue:
    kind: str
    command: str
    category: str
    detail: str


@dataclass
class CoverageResolver:
    scenario_map: dict[str, ScenarioDefinition]
    result_map: dict[str, str]
    exclusion_map: dict[tuple[str, str], dict]
    issue_list: list[CoverageIssue]

    def build_command_report(self, command: dict) -> dict:
        command_path = command["canonicalPath"]
        coverage_map = {
            category: self.resolve_category(command_path, category)
            for category in COVERAGE_CATEGORY_LIST
        }
        status_set = {item["status"] for item in coverage_map.values()}
        command["associatedScenarioIds"] = self._associated_scenario_ids(coverage_map)
        command["coverage"] = coverage_map
        command["coverageStatus"] = self._coverage_status(status_set)
        return command

    def resolve_category(self, command_path: str, category: str) -> dict:
        matching_scenario_list = [
            item
            for item in self.scenario_map.values()
            if category in item.coverage and (command_path in item.commands or "*" in item.commands)
        ]
        if matching_scenario_list:
            return self._resolve_scenario(command_path, category, matching_scenario_list)
        return self._resolve_exclusion(command_path, category)

    def _resolve_scenario(
        self,
        command_path: str,
        category: str,
        scenario_list: list[ScenarioDefinition],
    ) -> dict:
        scenario_id_list = sorted(item.id for item in scenario_list)
        status_list = [self.result_map.get(item.id, "not-executed") for item in scenario_list]
        if "passed" in status_list:
            return {"status": "passed", "scenarioIds": scenario_id_list}
        detail = f"Referenced scenarios did not pass in this run: {dict(zip(scenario_id_list, status_list))}"
        self.issue_list.append(CoverageIssue("scenario-not-passed", command_path, category, detail))
        return {"status": "not-passed", "scenarioIds": scenario_id_list}

    def _resolve_exclusion(self, command_path: str, category: str) -> dict:
        exclusion = self.exclusion_map.get((command_path, category))
        if exclusion is not None:
            return {
                "status": "excluded",
                "classification": exclusion["classification"],
                "reason": exclusion["reason"],
            }
        detail = "No executable scenario or exclusion exists."
        self.issue_list.append(CoverageIssue("missing-coverage", command_path, category, detail))
        return {"status": "missing", "scenarioIds": []}

    @staticmethod
    def _associated_scenario_ids(coverage_map: dict) -> list[str]:
        return sorted(
            {
                scenario_id
                for item in coverage_map.values()
                for scenario_id in item.get("scenarioIds", [])
            }
        )

    @staticmethod
    def _coverage_status(status_set: set[str]) -> str:
        if status_set <= {"passed"}:
            return "covered"
        if status_set <= {"passed", "excluded"}:
            return "excluded"
        return "uncovered"


def export_command_inventory(
    *,
    gerber_root: Path,
    output_path: Path,
    fixture_module_root: Path | None = None,
) -> list[dict]:
    exporter_path = gerber_root / "tests/terminal/fixtures/Export-GerberCommandInventory.ps1"
    argument_list = [
        "pwsh",
        "-NoLogo",
        "-NoProfile",
        "-File",
        str(exporter_path),
        "-GerberRoot",
        str(gerber_root),
        "-OutputPath",
        str(output_path),
    ]
    if fixture_module_root is not None:
        argument_list += ["-FixtureModuleRoot", str(fixture_module_root)]
    subprocess.run(argument_list, check=True, timeout=60)
    return json.loads(output_path.read_text(encoding="utf-8-sig"))


def load_exclusion_list(path: Path) -> list[dict]:
    if not path.exists():
        return []
    exclusion_list = []
    for item in json.loads(path.read_text(encoding="utf-8")):
        for category in item["categories"]:
            exclusion_list.append(
                {
                    "command": item["command"],
                    "category": category,
                    "classification": item["classification"],
                    "reason": item["reason"],
                }
            )
    return exclusion_list


def build_coverage_report(
    *,
    inventory: list[dict],
    scenario_list: Iterable[ScenarioDefinition],
    result_list: Iterable[object],
    exclusion_list: list[dict],
) -> dict:
    scenario_map = {item.id: item for item in scenario_list}
    result_map = {item.id: item.status for item in result_list}
    exclusion_map = _build_exclusion_map(exclusion_list)
    issue_list: list[CoverageIssue] = []
    resolver = CoverageResolver(scenario_map, result_map, exclusion_map, issue_list)
    command_report_list = [
        resolver.build_command_report(item)
        for item in inventory
    ]
    _find_stale_exclusions(inventory, exclusion_list, issue_list)
    return {
        "coverageCategories": COVERAGE_CATEGORY_LIST,
        "commandCount": len(command_report_list),
        "coveredCommandCount": sum(1 for item in command_report_list if item["coverageStatus"] == "covered"),
        "excludedCommandCount": sum(1 for item in command_report_list if item["coverageStatus"] == "excluded"),
        "uncoveredCommandCount": sum(1 for item in command_report_list if item["coverageStatus"] == "uncovered"),
        "commands": command_report_list,
        "issues": [asdict(item) for item in issue_list],
    }


def write_coverage_report(run_root: Path, report: dict, *, report_name: str = "command-coverage") -> None:
    (run_root / f"{report_name}.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    line_list = [
        "# Interactive command coverage",
        "",
        f"- Commands: {report['commandCount']}",
        f"- Covered: {report['coveredCommandCount']}",
        f"- Explicitly excluded: {report['excludedCommandCount']}",
        f"- Uncovered: {report['uncoveredCommandCount']}",
        "",
        "| Command | Owner | Status | Coverage |",
        "| --- | --- | --- | --- |",
    ]
    for command in report["commands"]:
        category_text = ", ".join(
            f"{name}: {value['status']}" for name, value in command["coverage"].items()
        )
        line_list.append(
            f"| `/{command['canonicalPath']}` | {command['ownerName']} | "
            f"{command['coverageStatus']} | {category_text} |"
        )
    (run_root / f"{report_name}.md").write_text("\n".join(line_list) + "\n", encoding="utf-8")


def _build_exclusion_map(exclusion_list: list[dict]) -> dict[tuple[str, str], dict]:
    return {
        (item["command"], item["category"]): item
        for item in exclusion_list
    }


def _find_stale_exclusions(
    inventory: list[dict],
    exclusion_list: list[dict],
    issue_list: list[CoverageIssue],
) -> None:
    command_set = {item["canonicalPath"] for item in inventory}
    for exclusion in exclusion_list:
        if exclusion["command"] not in command_set:
            issue_list.append(
                CoverageIssue(
                    "stale-exclusion",
                    exclusion["command"],
                    exclusion["category"],
                    "The excluded command is not present in the built registry.",
                )
            )
