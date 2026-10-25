from __future__ import annotations

import json

from framework.scenario_registry import ScenarioMetadata, scenario


def _seed_update(context, **options) -> None:
    root = context.app.runtime_paths.scenario_root
    (root / "config.json").write_text(
        json.dumps({"schemaVersion": 1}),
        encoding="utf-8",
    )
    fixture = {"disposition": "UpdateAvailable", "startupStatus": "Available", **options}
    (root / "update-fixture.json").write_text(json.dumps(fixture), encoding="utf-8")


def _open_update(context) -> None:
    context.app.type("/upd")
    context.app.expect_suggestion("/update")
    context.app.type("ate")
    context.app.press("ENTER")


def _update_state(context) -> dict:
    path = context.app.runtime_paths.scenario_root / "update-state.json"
    return json.loads(path.read_text(encoding="utf-8"))


def _assert_trace_order(context, *names: str) -> None:
    events = [json.loads(line)["Event"] for line in context.app.prompt_trace_text().splitlines() if line.strip()]
    offset = 0
    for name in names:
        offset = events.index(name, offset) + 1


@scenario(
    "update-accept-and-startup-notification",
    title="Core update acceptance and persistent startup notification",
    categories=("core", "updates", "startup"),
    metadata=ScenarioMetadata(
        commands=("update",), workflows=("command:update",),
        coverage=("discovery", "dispatch", "workflow", "rendering"),
    ),
)
def update_accept_and_startup_notification(context) -> None:
    _seed_update(context)
    context.app.start()
    context.app.wait_for_text("0.2.0 is available. Run /update")
    context.app.wait_for_prompt()
    assert _update_state(context)["installCount"] == 0
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.wait_for_text("PSGallery")
    context.app.expect_text_absent("Unconfigured")
    state = _update_state(context)
    assert state["startupDiscoveryCount"] == 1 and state["repository"] == "PSGallery", state
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("Restart PowerShell")
    context.app.wait_for_text("Press Enter to continue")
    assert _update_state(context)["installCount"] == 1
    context.app.press("ENTER")
    context.app.wait_for_text("0.2.0 is available. Run /update")
    _assert_trace_order(context, "update-discovery", "update-confirmation", "update-install-complete", "screen-transition")


@scenario(
    "update-default-cancel-and-escape",
    title="Core update safe default and local Escape navigation",
    categories=("core", "updates", "navigation"),
    metadata=ScenarioMetadata(
        commands=("update",), workflows=("command:update",),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def update_default_cancel_and_escape(context) -> None:
    _seed_update(context)
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update cancelled")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.press("ESCAPE")
    context.app.wait_for_text("Gerber - DevOps Multitool")
    context.app.wait_for_prompt()
    state = _update_state(context)
    assert state["installCount"] == 0 and state["discoveryCount"] == 2, state
    _assert_trace_order(context, "update-discovery", "update-confirmation", "update-discovery")


@scenario(
    "update-discovery-error-recovers",
    title="Offline update discovery recovers without leaking backend errors",
    categories=("core", "updates", "recovery"),
    metadata=ScenarioMetadata(
        commands=("update",), workflows=("command:update",),
        coverage=("dispatch", "workflow", "error-recovery", "rendering"),
    ),
)
def update_discovery_error_recovers(context) -> None:
    _seed_update(context, failDiscoveryCount=1, startupStatus="Unavailable")
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Update unavailable")
    context.app.expect_text_absent("raw-update-token")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update cancelled")
    assert _update_state(context)["installCount"] == 0
    _assert_trace_order(context, "update-discovery", "screen-transition", "update-discovery", "update-confirmation")
    assert "raw-update-token" not in context.app.prompt_trace_text()


@scenario(
    "update-install-error-recovers",
    title="Core install failure remains recoverable with truthful rollback guidance",
    categories=("core", "updates", "recovery"),
    metadata=ScenarioMetadata(
        commands=("update",), workflows=("command:update",),
        coverage=("dispatch", "workflow", "navigation", "error-recovery"),
    ),
)
def update_install_error_recovers(context) -> None:
    _seed_update(context, installError="PMU.RollbackFailed")
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("Installation and rollback failed")
    context.app.wait_for_text("Preserve PMU journals")
    context.app.expect_text_absent("raw-update-token")
    context.app.press("ENTER")
    context.app.wait_for_text("Gerber - DevOps Multitool")
    context.app.wait_for_prompt()
    _assert_trace_order(context, "update-discovery", "update-confirmation", "update-install-complete", "screen-transition")


@scenario(
    "update-no-update-overview",
    title="Core no-update overview shows explicit repository and version columns",
    categories=("core", "updates"),
    metadata=ScenarioMetadata(
        commands=("update",), workflows=("command:update",),
        coverage=("dispatch", "workflow", "rendering"),
    ),
)
def update_no_update_overview(context) -> None:
    _seed_update(context, disposition="UpToDate", startupStatus="UpToDate")
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Core is up to date")
    context.app.wait_for_text("Installed")
    context.app.wait_for_text("Available")
    context.app.wait_for_text("PSGallery")
    assert _update_state(context)["installCount"] == 0
    _assert_trace_order(context, "update-discovery")


@scenario(
    "update-no-core-config-no-matching-package",
    title="Unconfigured startup regression uses PSGallery without a Core binding",
    categories=("core", "updates", "startup"),
    metadata=ScenarioMetadata(
        commands=("update",), workflows=("command:update",),
        coverage=("discovery", "dispatch", "workflow", "rendering"),
    ),
)
def update_no_core_config_no_matching_package(context) -> None:
    _seed_update(context, noMatchingPackage=True)
    context.app.start()
    context.app.wait_for_prompt()
    assert _update_state(context)["startupDiscoveryCount"] == 1
    _open_update(context)
    context.app.wait_for_text("No eligible Gerber package")
    context.app.wait_for_text("PSGallery")
    context.app.expect_text_absent("Unconfigured")
    context.app.expect_text_absent("Core is up to date")
    context.app.expect_text_absent("Install Core update?")
    assert _update_state(context)["installCount"] == 0
    _assert_trace_order(context, "update-discovery")
