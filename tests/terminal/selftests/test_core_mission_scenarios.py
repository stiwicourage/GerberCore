from pathlib import Path
import sys
import unittest


TERMINAL_ROOT = Path(__file__).resolve().parents[1]
if str(TERMINAL_ROOT) not in sys.path:
    sys.path.insert(0, str(TERMINAL_ROOT))

from framework.scenario_registry import SCENARIO_REGISTRY  # noqa: E402
from scenarios.core_mission_support import (  # noqa: E402
    assert_confirmation_event,
    assert_http_request,
    assert_mutation_target,
    assert_no_secret_leak,
    assert_preview,
    assert_selected_text,
    strict_http_fixture,
)
from scenarios.repository_create_support import (  # noqa: E402
    CREATED_REPOSITORY_ID,
    REPOSITORY_NAME,
    assert_repository_create_failure_requests,
    assert_repository_create_isolation,
    assert_repository_create_success_requests,
    repository_create_failure_fixture,
    repository_create_success_fixture,
)


class FakeApp:
    def __init__(self, *, visible: str = "", raw: str = "", trace: str = "") -> None:
        self._visible = visible
        self._raw = raw
        self._trace = trace

    def visible_text(self) -> str:
        return self._visible

    def raw_output(self) -> str:
        return self._raw

    def prompt_trace_text(self) -> str:
        return self._trace


class FakeRepositoryApp:
    def __init__(self, root: Path) -> None:
        self.runtime_paths = type("RuntimePaths", (), {"scenario_root": root})()

    def http_state(self):
        return {
            "requests": [
                {"headers": {"Authorization": "<redacted>"}},
            ]
        }

    def credential_state(self):
        return {
            "credentials": {"gerber:ado:terminal:pat": "terminal-ado-pat"},
            "operations": [
                {
                    "operation": "Get",
                    "service": "credentials",
                    "account": "gerber:ado:terminal:pat",
                }
            ] * 6,
            "failures": {},
        }


class CoreMissionScenarioSupportTests(unittest.TestCase):
    def test_requested_core_mission_scenarios_are_registered(self) -> None:
        scenario_id_set = {item.id for item in SCENARIO_REGISTRY}

        self.assertTrue(
            {
                "core-mission-ado-agents-success",
                "core-mission-ado-agents-recovery",
                "core-mission-branch-find",
                "core-mission-branch-set-default",
                "core-mission-branch-set-searchable",
                "core-mission-repository-create",
                "core-mission-repository-create-recovery",
                "core-mission-pipeline-tags-delete",
                "core-mission-pipeline-tags-update",
                "core-mission-secrets-lifecycle",
            }.issubset(scenario_id_set)
        )

    def test_strict_fixture_rejects_unexpected_requests(self) -> None:
        fixture = strict_http_fixture([])

        self.assertEqual(
            fixture["defaultResult"],
            {
                "type": "error",
                "message": "Unexpected Gerber Core terminal HTTP request.",
            },
        )

    def test_http_request_assertion_rejects_wrong_method_uri_and_body(self) -> None:
        request = {
            "method": "Patch",
            "uri": "https://example.test/repositories/1",
            "body": {"defaultBranch": "refs/heads/main"},
        }

        for override in (
            {"method": "Post"},
            {"uri": "https://example.test/repositories/2"},
            {"body": {"defaultBranch": "refs/heads/develop"}},
        ):
            expected = dict(request)
            expected.update(override)
            with self.assertRaises(AssertionError):
                assert_http_request(request, **expected)

    def test_evidence_assertions_reject_wrong_selection_preview_and_target(self) -> None:
        with self.assertRaises(AssertionError):
            assert_selected_text("Selected: Repository A", "Repository B")
        with self.assertRaises(AssertionError):
            assert_preview("Preview: Apply to Repository A", "Repository B")
        with self.assertRaises(AssertionError):
            assert_mutation_target(
                [{"method": "Patch", "uri": "https://example.test/repositories/1"}],
                "https://example.test/repositories/2",
            )

    def test_confirmation_assertion_rejects_missing_confirmation(self) -> None:
        with self.assertRaises(AssertionError):
            assert_confirmation_event('{"Event":"different-event","Data":{}}', "expected-event")

    def test_secret_leak_detection_checks_screen_raw_output_and_trace(self) -> None:
        for app in (
            FakeApp(visible="secret-value"),
            FakeApp(raw="secret-value"),
            FakeApp(trace="secret-value"),
        ):
            with self.assertRaises(AssertionError):
                assert_no_secret_leak(app, "secret-value")

    def test_repository_create_success_fixture_covers_complete_provisioning_chain(self) -> None:
        fixture = repository_create_success_fixture()
        request_list = fixture["requests"]

        self.assertEqual(request_list[3]["response"]["id"], CREATED_REPOSITORY_ID)
        self.assertEqual(request_list[5]["rawContent"], "# PackageName\n")
        self.assertEqual(request_list[7]["expectedBody"]["commits"][0]["changes"][0]["newContent"]["content"], f"# {REPOSITORY_NAME}\n")
        self.assertEqual(request_list[-3]["expectedBody"]["settings"]["requiredReviewerIds"], ["team-core"])
        assert_repository_create_success_requests(_request_log_from_fixture(request_list))

    def test_repository_create_failure_fixture_preserves_controlled_recovery_path(self) -> None:
        fixture = repository_create_failure_fixture()
        request_list = fixture["requests"]

        self.assertEqual(request_list[3]["error"]["message"], "Synthetic repository creation failure.")
        assert_repository_create_failure_requests(_request_log_from_fixture(request_list))

    def test_repository_create_request_assertions_reject_incomplete_chain(self) -> None:
        request_list = _request_log_from_fixture(repository_create_success_fixture()["requests"])

        with self.assertRaises(AssertionError):
            assert_repository_create_success_requests(request_list[:-1])

    def test_repository_create_isolation_assertion_accepts_sanitized_isolated_state(self) -> None:
        from tempfile import TemporaryDirectory

        with TemporaryDirectory() as directory:
            scenario_root = Path(directory)
            (scenario_root / "home").mkdir()
            (scenario_root / "temp").mkdir()
            (scenario_root / "xdg-config").mkdir()
            (scenario_root / "config.json").write_text(
                '{"ado":{"profiles":{"terminal":{"projectUrl":"https://dev.azure.com/terminal/TerminalProject"}}}}',
                encoding="utf-8",
            )

            assert_repository_create_isolation(FakeRepositoryApp(scenario_root))


def _request_log_from_fixture(request_list):
    return [
        {
            "method": request["method"],
            "uri": request["uri"],
            "body": request.get("expectedBody", {}),
            "transport": "Invoke-WebRequest" if "rawContent" in request else "Invoke-RestMethod",
        }
        for request in request_list
    ]


if __name__ == "__main__":
    unittest.main()
