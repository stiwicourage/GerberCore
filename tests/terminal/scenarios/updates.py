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
    context.app.type("ate list")
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
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
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
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
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
    context.app.expect_input("/update ")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
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
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
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
    context.app.expect_input("/update ")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
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
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
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
    "update-missing-provider-metadata-recovers",
    title="Locally copied Core installation receives actionable recovery guidance",
    categories=("core", "updates", "recovery"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "navigation", "error-recovery", "rendering"),
    ),
)
def update_missing_provider_metadata_recovers(context) -> None:
    _seed_update(
        context, installError="PMU.UnsupportedInstallation",
        installErrorMessage="The selected installation has no native provider metadata.",
    )
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("no native provider metadata")
    context.app.wait_for_text("locally copied or published")
    context.app.wait_for_text("Press Enter to continue")
    screen = context.app.visible_text().replace("\n", "")
    assert "Reinstall the current Gerber version from PSGallery" in screen, screen
    context.app.expect_text_absent("supported numeric-version module directory")
    context.app.expect_text_absent("raw-update-token")
    context.app.press("ENTER")
    context.app.wait_for_text("Gerber - DevOps Multitool")
    _assert_trace_order(context, "update-discovery", "update-confirmation", "update-install-complete", "screen-transition")


@scenario(
    "update-no-update-overview",
    title="Core equal-version overview preserves PMU availability without an install offer",
    categories=("core", "updates"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "rendering"),
    ),
)
def update_no_update_overview(context) -> None:
    _seed_update(
        context, disposition="UpToDate", startupStatus="UpToDate",
        installedVersion="0.1.0", targetVersion="0.1.0",
    )
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Core is up to date")
    context.app.wait_for_text("Installed")
    context.app.wait_for_text("Available")
    context.app.wait_for_text("PSGallery")
    context.app.wait_for_text("UpToDate")
    row = next(line for line in context.app.visible_text().splitlines() if "PSGallery" in line)
    assert row.split() == ["Core", "Gerber", "0.1.0", "0.1.0", "PSGallery", "UpToDate"], row
    context.app.expect_text_absent("Install Core update?")
    assert _update_state(context)["installCount"] == 0
    _assert_trace_order(context, "update-discovery")
    assert "update-confirmation" not in context.app.prompt_trace_text()


@scenario(
    "update-no-core-config-no-matching-package",
    title="Unconfigured startup regression uses PSGallery without a Core binding",
    categories=("core", "updates", "startup"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
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


@scenario(
    "update-unsupported-installation",
    title="Unsupported installation gives layout guidance without blaming PSGallery",
    categories=("core", "updates", "recovery"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "navigation", "error-recovery", "rendering"),
    ),
)
def update_unsupported_installation(context) -> None:
    _seed_update(context, discoveryError="PMU.UnsupportedInstallation", startupStatus="Unavailable")
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("current installation layout")
    context.app.wait_for_text("supported numeric-version")
    context.app.wait_for_text("restart PowerShell")
    assert "supported numeric-version module directory" in context.app.visible_text().replace("\n", "")
    context.app.expect_text_absent("registration and connection")
    context.app.expect_text_absent("raw-update-token")
    context.app.expect_text_absent("Install Core update?")
    context.app.expect_text_absent("Core is up to date")
    assert _update_state(context)["installCount"] == 0
    _assert_trace_order(context, "update-discovery")
    assert "update-confirmation" not in context.app.prompt_trace_text()
    context.app.press("ENTER")
    context.app.wait_for_prompt()


def _open_policy(context) -> None:
    context.app.type("/update ")
    _choose_policy(context)


def _choose_policy(context) -> None:
    context.app.type("pol")
    context.app.expect_suggestion("/update policy")
    context.app.press("TAB")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update channel (Esc to go back)")


def _continue_to_update_menu(context) -> None:
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.wait_for_text("[list|policy]")
    context.app.expect_selected_suggestion_highlighted("/update list")
    context.app.expect_text_absent("Core update channel (Esc to go back)")


@scenario(
    "update-policy-persistence-and-navigation",
    title="Core channel selection persists, invalidates notification and keeps update safety",
    categories=("core", "updates", "policy"),
    metadata=ScenarioMetadata(
        commands=("update policy", "update", "update list"),
        workflows=("command:update policy", "command:update", "command:update list"),
        coverage=("discovery", "dispatch", "workflow", "navigation", "rendering"),
    ),
)
def update_policy_persistence_and_navigation(context) -> None:
    _seed_update(context)
    context.app.start()
    context.app.wait_for_prompt()
    _open_policy(context)
    context.app.wait_for_text("Current Core update policy: Stable only")
    before = _update_state(context)
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update policy saved: Include prereleases")
    context.app.wait_for_text("Nothing was installed")
    config = context.app.runtime_paths.scenario_root / "config.json"
    assert json.loads(config.read_text())["coreUpdates"]["channel"] == "IncludePrerelease"
    assert _update_state(context)["discoveryCount"] == before["discoveryCount"]
    _continue_to_update_menu(context)
    _choose_policy(context)
    context.app.wait_for_text("Current Core update policy: Include prereleases")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update policy unchanged: Include prereleases")
    _continue_to_update_menu(context)
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
    context.app.expect_text_absent("0.2.0 is available. Run /update")
    _open_policy(context)
    context.app.wait_for_text("Current Core update policy: Include prereleases")
    context.app.press("DOWN")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
    assert json.loads(config.read_text())["coreUpdates"]["channel"] == "IncludePrerelease"
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.wait_for_text("Channel: Include prereleases")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update cancelled")
    state = _update_state(context)
    assert state["channel"] == "IncludePrerelease" and state["installCount"] == 0, state
    _assert_trace_order(context, "numbered-submit", "update-policy-saved", "screen-transition",
                        "numbered-open", "numbered-submit", "update-policy-saved", "screen-transition",
                        "numbered-open",
                        "numbered-cancel", "update-discovery", "update-confirmation")


@scenario(
    "update-policy-save-error-recovers",
    title="Failed Core channel save preserves configuration and retries from the update menu",
    categories=("core", "updates", "policy", "recovery"),
    metadata=ScenarioMetadata(
        commands=("update policy", "update"), workflows=("command:update policy", "command:update"),
        coverage=("dispatch", "workflow", "navigation", "rendering", "error-recovery"),
    ),
)
def update_policy_save_error_recovers(context) -> None:
    _seed_update(context, failPolicySaveCount=1)
    context.app.start()
    context.app.wait_for_prompt()
    _open_policy(context)
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("Gerber could not save the Core update policy")
    context.app.wait_for_text("write permissions")
    context.app.expect_text_absent("Core update policy saved:")
    config = context.app.runtime_paths.scenario_root / "config.json"
    assert "coreUpdates" not in json.loads(config.read_text())
    _continue_to_update_menu(context)
    _choose_policy(context)
    context.app.wait_for_text("Current Core update policy: Stable only")
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update policy saved: Include prereleases")
    assert json.loads(config.read_text())["coreUpdates"]["channel"] == "IncludePrerelease"
    assert _update_state(context)["installCount"] == 0
    _continue_to_update_menu(context)
    _assert_trace_order(context, "numbered-submit", "update-policy-save-failed", "screen-transition",
                        "numbered-open", "numbered-submit", "update-policy-saved", "screen-transition")


@scenario(
    "update-shared-submenu",
    title="Update uses the shared list/policy chooser with local back navigation",
    categories=("core", "updates", "navigation"),
    metadata=ScenarioMetadata(
        commands=("update", "update list", "update policy"),
        workflows=("command:update", "command:update list", "command:update policy"),
        coverage=("discovery", "dispatch", "workflow", "navigation", "rendering"),
    ),
)
def update_shared_submenu(context) -> None:
    _seed_update(context)
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/update")
    context.app.press("ENTER")
    context.app.expect_input("/update ")
    context.app.wait_for_text("[list|policy]")
    context.app.expect_suggestion("/update list")
    context.app.expect_suggestion("/update policy")
    context.app.expect_selected_suggestion_highlighted("/update list")
    assert _update_state(context)["discoveryCount"] == 0
    context.app.press("ENTER")
    context.app.wait_for_text("Install Core update?")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update cancelled")
    context.app.press("ENTER")
    context.app.expect_input("/update ")
    context.app.expect_selected_suggestion_highlighted("/update list")
    context.app.press("ENTER")
    context.app.wait_for_text("Install Core update?")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.expect_selected_suggestion_highlighted("/update list")
    context.app.type("pol")
    context.app.press("TAB")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update channel (Esc to go back)")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.expect_selected_suggestion_highlighted("/update list")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
    assert _update_state(context)["installCount"] == 0
