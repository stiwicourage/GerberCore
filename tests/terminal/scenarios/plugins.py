from __future__ import annotations

import json
from dataclasses import replace
from pathlib import Path
import subprocess
import time

from framework.scenario_registry import ScenarioMetadata, scenario

from .core import _press_double_escape
from .core_mission_support import (
    ADO_PAT,
    assert_no_secret_leak,
    seed_ado_state,
    strict_http_fixture,
)


SYNTHETIC_PLUGIN_MESSAGE = "Synthetic plugin command executed."
SYNTHETIC_PLUGIN_FAILURE = "Synthetic plugin failure."
SYNTHETIC_EMPTY_TITLE = "/repository empty-text"
PLUGIN_SECRET = "terminal-plugin-secret"
PLUGIN_GUID = "7dd21b37-e080-4240-b05f-ec727389035e"
PLUGIN_CREATION_INPUT_BATCH_SIZE = 64


def _start_plugin_creation_session(context) -> None:
    options = context.app._options
    module_root = options.runtime_paths.scenario_root / "development-modules"
    module_root.mkdir()
    (module_root / "Gerber.TerminalFixture").symlink_to(
        options.synthetic_plugin_root / "Gerber.TerminalFixture", target_is_directory=True
    )
    command = (
        "Import-Module NovaModuleTools,PSModuleUpdate; Get-Module | "
        "Where-Object Name -In NovaModuleTools,PSModuleUpdate,Pester,PSScriptAnalyzer,Microsoft.PowerShell.PlatyPS | "
        "Select-Object Name,@{Name='Version';Expression={[string]$_.Version}},ModuleBase | ConvertTo-Json -Compress"
    )
    result = subprocess.run(
        ["pwsh", "-NoLogo", "-NoProfile", "-Command", command],
        capture_output=True, text=True, check=True, timeout=30,
    )
    for module in json.loads(result.stdout):
        target = module_root / module["Name"] / module["Version"]
        target.parent.mkdir(exist_ok=True)
        target.symlink_to(module["ModuleBase"], target_is_directory=True)
    context.app._options = replace(options, synthetic_plugin_root=module_root)
    context.app.start(enable_synthetic_plugin=True)
    approve_synthetic_plugin(context)


def _submit_plugin_creation_field(context, prompt: str, value: str) -> None:
    context.app.wait_for_text(prompt)
    # Drain long input incrementally without extending screen-stability deadlines.
    for offset in range(0, len(value), PLUGIN_CREATION_INPUT_BATCH_SIZE):
        context.app.type(value[offset:offset + PLUGIN_CREATION_INPUT_BATCH_SIZE])
    context.app.press("ENTER")


def _assert_plugin_creation_trace(context) -> None:
    events = [json.loads(line)["Event"] for line in context.app.prompt_trace_text().splitlines()]
    cursor = events.index("prompt-escape")
    for event in (
        "plugin-create-input-rejected",
        "plugin-create-validation-started", "plugin-create-validation-passed",
        "plugin-approval-persisted", "plugin-create-completed",
    ):
        cursor = events.index(event, cursor + 1)


@scenario(
    "plugin-create-workflow",
    title="Plugin create fixed-prefix input, Escape, recovery and validated approval",
    categories=("core", "plugin-create", "plugins", "navigation", "recovery"),
    metadata=ScenarioMetadata(
        commands=("plugins", "plugins create"),
        workflows=("command:plugins create",),
        coverage=("discovery", "dispatch", "workflow", "navigation", "rendering", "error-recovery"),
    ),
)
def plugin_create_workflow(context) -> None:
    _start_plugin_creation_session(context)
    config_path = context.app.runtime_paths.scenario_root / "config.json"
    before = config_path.read_text()
    _open_plugins_parent_menu(context)
    context.app.press("ENTER")
    context.app.wait_for_text("Create Gerber Plugin")
    context.app.wait_for_text("Module suffix")
    context.app.press("ESCAPE")
    _expect_plugins_parent_menu(context)
    assert config_path.read_text() == before, "Escape must not persist a generated approval"
    context.app.press("ENTER")
    _submit_plugin_creation_field(context, "Module suffix", "../bad")
    context.app.wait_for_text("Enter a module suffix")
    _submit_plugin_creation_field(context, "Module suffix", "MyCompany")
    _submit_plugin_creation_field(context, "Description", "PTY example")
    _submit_plugin_creation_field(context, "Command namespace", "tools")
    context.app.wait_for_text("already registered")
    _submit_plugin_creation_field(context, "Command namespace", "mycompany")
    context.app.wait_for_text("Select the parent directory")
    context.app.wait_for_text("Default:")
    context.app.wait_for_text("Project directory:")
    _submit_plugin_creation_field(context, "Destination parent", str(context.app.runtime_paths.scenario_root))
    context.app.wait_for_text("Gerber Plugin Created", timeout_seconds=120)
    for text in ("Gerber.MyCompany", "Version:    0.1.0", "Namespace:  /mycompany",
                 "Approval:   Approved", "Associated: Yes", "Enabled:    Yes",
                 "Installed:  No", "Publish-NovaModule -Local", "/mycompany hello"):
        context.app.wait_for_text(text)
    project_path = context.app.runtime_paths.scenario_root / "Gerber.MyCompany"
    project = json.loads((project_path / "project.json").read_text())
    guid = project["Manifest"]["GUID"]
    config = json.loads(config_path.read_text())
    assert guid in config["plugins"]["approved"]
    assert config["plugins"]["associated"][guid]["enabled"] is True
    assert config["plugins"]["associated"][guid]["name"] == "Gerber.MyCompany"
    assert config["plugins"]["associated"][guid]["version"] == "0.1.0"
    assert "Guid" not in project["Manifest"]["PrivateData"]["Gerber"]
    _assert_plugin_creation_trace(context)
    context.app.press("ENTER")
    _expect_plugins_parent_menu(context)
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.type("/plugins list")
    context.app.press("ENTER")
    context.app.wait_for_text("Gerber.MyCompany")
    context.app.wait_for_text("0.1.0")
    context.app.wait_for_text("Missing")


def approve_synthetic_plugin(context) -> None:
    context.app.wait_for_text("Unknown Gerber plugin detected")
    context.app.wait_for_text(PLUGIN_GUID)
    context.app.expect_selected_suggestion("1. Decline")
    context.app.press("DOWN")
    context.app.expect_selected_suggestion("2. Approve")
    context.app.press("ENTER")
    context.app.wait_for_prompt()


def _start_plugin_management_session(context) -> None:
    context.app.start(enable_synthetic_plugin=True)
    approve_synthetic_plugin(context)
    context.app.close()

    context.app.start(enable_synthetic_plugin=True)
    context.app.wait_for_prompt()


def _open_plugin_info_view(context) -> None:
    _start_plugin_management_session(context)
    context.app.type("/plugins list")
    context.app.press("ENTER")
    context.app.wait_for_text("/plugins list")
    context.app.wait_for_text(PLUGIN_GUID)
    context.app.press("ENTER")
    context.app.wait_for_text("/plugins info")
    context.app.wait_for_text(f"GUID:         {PLUGIN_GUID}")


def _open_plugins_parent_menu(context) -> None:
    context.app.type("/plugins")
    context.app.press("ENTER")
    _expect_plugins_parent_menu(context)


def _expect_plugins_parent_menu(context) -> None:
    context.app.wait_for_text("/plugins")
    context.app.expect_text_absent("Gerber Plugins")
    context.app.wait_for_prompt()
    context.app.expect_input("/plugins ")
    context.app.expect_selected_suggestion_highlighted("/plugins create")


def _select_plugins_info_from_parent(context) -> None:
    context.app.press("DOWN")
    context.app.press("DOWN")
    context.app.press("DOWN")
    context.app.expect_selected_suggestion_highlighted("/plugins info")
    context.app.press("ENTER")


def _select_plugins_list_from_parent(context) -> None:
    for _ in range(4):
        context.app.press("DOWN")
    context.app.expect_selected_suggestion_highlighted("/plugins list")
    context.app.press("ENTER")
    context.app.wait_for_text("/plugins list")
    context.app.wait_for_text(PLUGIN_GUID)


def _return_to_root_from_plugins_parent(context) -> None:
    time.sleep(0.7)
    context.app.press("ESCAPE")
    context.app.wait_for_text("/branch")
    context.app.wait_for_prompt()
    context.app.expect_input("/")
    context.app.expect_selected_suggestion("/exit")


@scenario(
    "synthetic-plugin-discovery",
    title="Synthetic plugin discovery",
    categories=("plugin", "synthetic"),
    metadata=ScenarioMetadata(
        commands=(
            "repository empty-text",
            "repository explode",
            "repository fixture-ado",
            "repository fixture-api",
            "repository fixture-status",
        ),
        workflows=("plugin:discovery",),
        coverage=("discovery",),
    ),
)
def synthetic_plugin_discovery(context) -> None:
    context.app.start(enable_synthetic_plugin=True)
    approve_synthetic_plugin(context)
    context.app.type("/repository")
    context.app.expect_suggestion("/repository create")
    context.app.expect_suggestion("/repository empty-text")
    context.app.expect_suggestion("/repository explode")
    context.app.expect_suggestion("/repository fixture-ado")
    context.app.expect_suggestion("/repository fixture-api")
    context.app.expect_suggestion("/repository fixture-status")
    context.app.expect_text_absent("/synthetic")


@scenario(
    "synthetic-plugin-command-dispatch",
    title="Synthetic plugin dispatch",
    categories=("plugin", "synthetic"),
    metadata=ScenarioMetadata(
        commands=("repository fixture-status",),
        workflows=("command:repository fixture-status",),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def synthetic_plugin_command_dispatch(context) -> None:
    context.app.start(enable_synthetic_plugin=True)
    approve_synthetic_plugin(context)
    context.app.type("/repository fixture-status")
    context.app.press("ENTER")
    context.app.wait_for_text(SYNTHETIC_PLUGIN_MESSAGE)
    context.app.wait_for_text("Press Enter to continue:")


@scenario(
    "synthetic-plugin-controlled-failure",
    title="Synthetic plugin controlled failure",
    categories=("plugin", "synthetic", "errors", "recovery"),
    metadata=ScenarioMetadata(
        commands=("repository explode",),
        workflows=("command:repository explode", "plugin:controlled-failure"),
        coverage=("dispatch", "workflow", "navigation", "rendering", "error-recovery"),
    ),
)
def synthetic_plugin_controlled_failure(context) -> None:
    context.app.start(enable_synthetic_plugin=True)
    approve_synthetic_plugin(context)
    context.app.type("/repository explode")
    context.app.press("ENTER")
    context.app.wait_for_text(SYNTHETIC_PLUGIN_FAILURE)
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.type("/help")
    context.app.press("ENTER")
    context.app.wait_for_text("/help")


@scenario(
    "synthetic-plugin-empty-text-regression",
    title="Synthetic empty text regression",
    categories=("plugin", "synthetic", "regression"),
    metadata=ScenarioMetadata(
        commands=("repository empty-text",),
        workflows=("command:repository empty-text",),
        coverage=("dispatch", "workflow", "navigation", "rendering", "error-recovery"),
    ),
)
def synthetic_plugin_empty_text_regression(context) -> None:
    context.app.start(enable_synthetic_plugin=True)
    approve_synthetic_plugin(context)
    context.app.type("/repository empty-text")
    context.app.press("ENTER")
    context.app.wait_for_text("/repository empty-text")
    context.app.wait_for_prompt()
    context.app.expect_text_absent("Cannot bind argument to parameter 'Text' because it is an empty string.")


@scenario(
    "synthetic-plugin-api-contract",
    title="Generic Plugin API shared capability contract",
    categories=("plugin", "synthetic", "credentials", "clipboard"),
    metadata=ScenarioMetadata(
        commands=("repository fixture-api",),
        workflows=("command:repository fixture-api", "plugin-api:shared-capabilities"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def synthetic_plugin_api_contract(context) -> None:
    context.app.register_sensitive_value(PLUGIN_SECRET)
    context.app.start(enable_synthetic_plugin=True)
    approve_synthetic_plugin(context)
    context.app.type("/repository fixture-api")
    context.app.press("ENTER")
    context.app.wait_for_text("Synthetic Plugin API contract passed.")
    credential_state = context.app.credential_state()
    assert credential_state["credentials"] == {}, credential_state
    assert context.app.clipboard_state()["values"] == [
        {"value": "fixture-api-ok", "length": len("fixture-api-ok")}
    ]
    assert_no_secret_leak(context.app, PLUGIN_SECRET)


@scenario(
    "synthetic-plugin-ado-contract",
    title="Generic Plugin API ADO contract",
    categories=("plugin", "synthetic", "ado"),
    metadata=ScenarioMetadata(
        commands=("repository fixture-ado",),
        workflows=("command:repository fixture-ado", "plugin-api:ado"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def synthetic_plugin_ado_contract(context) -> None:
    seed_ado_state(context)
    fixture = strict_http_fixture(
        [
            {
                "method": "Get",
                "uri": "https://dev.azure.com/terminal/_apis/projects?api-version=7.0",
                "response": {"value": [{"id": "terminal", "name": "TerminalProject"}]},
            }
        ]
    )
    context.app.start(enable_synthetic_plugin=True, http_fixture=fixture)
    approve_synthetic_plugin(context)
    context.app.type("/repository fixture-ado")
    context.app.press("ENTER")
    context.app.wait_for_text("Synthetic Plugin API ADO contract passed for TerminalProject.")
    request_list = context.app.http_state()["requests"]
    assert len(request_list) == 1, request_list
    assert_no_secret_leak(context.app, ADO_PAT)


@scenario(
    "synthetic-plugin-ado-recovery",
    title="Generic Plugin API ADO failure recovery",
    categories=("plugin", "synthetic", "ado", "recovery"),
    metadata=ScenarioMetadata(
        commands=("repository fixture-ado",),
        workflows=("command:repository fixture-ado", "plugin-api:ado-failure"),
        coverage=("error-recovery",),
    ),
)
def synthetic_plugin_ado_recovery(context) -> None:
    seed_ado_state(context)
    context.app.start(
        enable_synthetic_plugin=True,
        http_fixture=strict_http_fixture([]),
    )
    approve_synthetic_plugin(context)
    context.app.type("/repository fixture-ado")
    context.app.press("ENTER")
    context.app.wait_for_text("Unexpected Gerber Core terminal HTTP request.")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    assert_no_secret_leak(context.app, ADO_PAT)


@scenario(
    "synthetic-plugin-approval-persistence",
    title="Synthetic plugin approval persistence",
    categories=("plugin", "synthetic", "approval"),
    metadata=ScenarioMetadata(
        commands=(),
        workflows=("plugin:approval", "plugin:approval-persistence"),
        coverage=(),
    ),
)
def synthetic_plugin_approval_persistence(context) -> None:
    context.app.start(enable_synthetic_plugin=True)
    approve_synthetic_plugin(context)
    event_map = {
        item["Event"]: item["Data"]
        for item in (
            json.loads(line)
            for line in context.app.prompt_trace_text().splitlines()
            if line.strip()
        )
    }
    assert event_map["plugin-approval-decision"]["Approved"] is True, event_map
    assert event_map["plugin-approval-persisted"]["Guid"] == PLUGIN_GUID, event_map
    context.app.close()

    context.app.start(enable_synthetic_plugin=True)
    context.app.wait_for_prompt()
    context.app.type("/repository")
    context.app.expect_suggestion("/repository fixture-status")
    context.app.expect_text_absent("Unknown Gerber plugin detected")


@scenario(
    "synthetic-plugin-approval-declined",
    title="Synthetic plugin approval declined",
    categories=("plugin", "synthetic", "approval"),
    metadata=ScenarioMetadata(
        commands=(),
        workflows=("plugin:approval-declined",),
        coverage=(),
    ),
)
def synthetic_plugin_approval_declined(context) -> None:
    context.app.start(enable_synthetic_plugin=True)
    context.app.wait_for_text("Unknown Gerber plugin detected")
    context.app.expect_selected_suggestion("1. Decline")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    event_map = {
        item["Event"]: item["Data"]
        for item in (
            json.loads(line)
            for line in context.app.prompt_trace_text().splitlines()
            if line.strip()
        )
    }
    assert event_map["plugin-approval-decision"]["Approved"] is False, event_map
    context.app.close()

    context.app.start(enable_synthetic_plugin=True)
    context.app.wait_for_prompt()
    context.app.type("/repository")
    context.app.expect_text_absent("/repository fixture-status")
    context.app.press("ESCAPE")
    context.app.type("/help")
    context.app.press("ENTER")
    context.app.wait_for_text("/help")


@scenario(
    "plugin-management-read-only",
    title="Core plugin management read-only views",
    categories=("plugin", "core", "rendering", "navigation"),
    metadata=ScenarioMetadata(
        commands=("plugins", "plugins list", "plugins info"),
        workflows=("command:plugins", "command:plugins list", "command:plugins info"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def plugin_management_read_only(context) -> None:
    context.app.start(enable_synthetic_plugin=True)
    approve_synthetic_plugin(context)
    context.app.close()

    context.app.start(enable_synthetic_plugin=True)
    context.app.wait_for_prompt()
    _open_plugins_parent_menu(context)
    context.app.wait_for_text("/plugins info")
    _select_plugins_info_from_parent(context)
    context.app.wait_for_text("Plugin GUID or unique module name:")
    context.app.type(PLUGIN_GUID)
    context.app.press("ENTER")
    context.app.wait_for_text("/plugins info")
    context.app.wait_for_text(f"GUID:         {PLUGIN_GUID}")
    context.app.wait_for_text("Approval:     Approved")
    context.app.press("ENTER")
    context.app.wait_for_prompt()


@scenario(
    "plugin-enable-disable-workflow",
    title="Core plugin disable and enable take effect immediately",
    categories=("plugin", "core", "rendering", "navigation"),
    metadata=ScenarioMetadata(
        commands=("plugins", "plugins enable", "plugins disable"),
        workflows=("command:plugins", "command:plugins enable", "command:plugins disable"),
        coverage=("dispatch", "workflow", "navigation", "rendering", "error-recovery"),
    ),
)
def plugin_enable_disable_workflow(context) -> None:
    _start_plugin_management_session(context)
    context.app.type("/plugins disable")
    context.app.press("ENTER")
    context.app.wait_for_text("Select plugin")
    context.app.press("ENTER")
    context.app.wait_for_text("Disabled plugin")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.type("disable")
    context.app.press("ENTER")
    context.app.wait_for_text("No enabled Gerber plugins are available to disable.")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.type("enable")
    context.app.press("ENTER")
    context.app.wait_for_text("Select plugin")
    context.app.press("ENTER")
    context.app.wait_for_text("Enabled and approved plugin")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.type("enable")
    context.app.press("ENTER")
    context.app.wait_for_text("No installed Gerber plugins are available to enable.")
    context.app.press("ENTER")
    context.app.wait_for_prompt()


@scenario(
    "plugin-menu-list-parent-navigation",
    title="Plugin list single Escape returns to /plugins",
    categories=("plugin", "core", "escape", "navigation"),
    metadata=ScenarioMetadata(
        commands=("plugins", "plugins list"),
        workflows=("command:plugins", "command:plugins list", "navigation:single-escape"),
        coverage=("workflow", "navigation", "rendering"),
    ),
)
def plugin_menu_list_parent_navigation(context) -> None:
    _start_plugin_management_session(context)
    _open_plugins_parent_menu(context)
    _select_plugins_list_from_parent(context)
    context.app.press("ESCAPE")
    _expect_plugins_parent_menu(context)
    _return_to_root_from_plugins_parent(context)


@scenario(
    "plugin-menu-info-parent-navigation",
    title="Plugin info single Escape returns to /plugins",
    categories=("plugin", "core", "escape", "navigation"),
    metadata=ScenarioMetadata(
        commands=("plugins", "plugins info"),
        workflows=("command:plugins", "command:plugins info", "navigation:single-escape"),
        coverage=("workflow", "navigation", "rendering"),
    ),
)
def plugin_menu_info_parent_navigation(context) -> None:
    _start_plugin_management_session(context)
    _open_plugins_parent_menu(context)
    _select_plugins_info_from_parent(context)
    context.app.wait_for_text("Plugin GUID or unique module name:")
    context.app.press("ESCAPE")
    _expect_plugins_parent_menu(context)
    _return_to_root_from_plugins_parent(context)


@scenario(
    "plugin-details-parent-navigation",
    title="Plugin details single Escape returns to list then /plugins",
    categories=("plugin", "core", "escape", "navigation"),
    metadata=ScenarioMetadata(
        commands=("plugins", "plugins list", "plugins info"),
        workflows=("command:plugins", "command:plugins list", "command:plugins info", "navigation:single-escape"),
        coverage=("workflow", "navigation", "rendering"),
    ),
)
def plugin_details_parent_navigation(context) -> None:
    _start_plugin_management_session(context)
    _open_plugins_parent_menu(context)
    _select_plugins_list_from_parent(context)
    context.app.press("ENTER")
    context.app.wait_for_text("/plugins info")
    context.app.wait_for_text(f"GUID:         {PLUGIN_GUID}")
    context.app.press("ESCAPE")
    context.app.wait_for_text("/plugins list")
    context.app.wait_for_text(PLUGIN_GUID)
    context.app.press("ESCAPE")
    _expect_plugins_parent_menu(context)


@scenario(
    "plugin-menu-repeated-navigation-highlight",
    title="Plugin menu keeps highlight after repeated Escape navigation",
    categories=("plugin", "core", "escape", "navigation", "rendering"),
    metadata=ScenarioMetadata(
        commands=("plugins", "plugins info", "plugins list"),
        workflows=("command:plugins", "command:plugins info", "command:plugins list", "navigation:single-escape"),
        coverage=("workflow", "navigation", "rendering"),
    ),
)
def plugin_menu_repeated_navigation_highlight(context) -> None:
    _start_plugin_management_session(context)
    _open_plugins_parent_menu(context)
    _select_plugins_info_from_parent(context)
    context.app.wait_for_text("Plugin GUID or unique module name:")
    context.app.press("ESCAPE")
    _expect_plugins_parent_menu(context)
    _select_plugins_list_from_parent(context)
    context.app.press("ESCAPE")
    _expect_plugins_parent_menu(context)


@scenario(
    "plugin-list-double-escape-to-root",
    title="Plugin list double Escape returns to root",
    categories=("plugin", "core", "escape", "navigation"),
    metadata=ScenarioMetadata(
        commands=("plugins", "plugins list"),
        workflows=("command:plugins", "command:plugins list", "navigation:double-escape-root"),
        coverage=("workflow", "navigation", "rendering"),
    ),
)
def plugin_list_double_escape_to_root(context) -> None:
    _start_plugin_management_session(context)
    _open_plugins_parent_menu(context)
    _select_plugins_list_from_parent(context)
    _press_double_escape(context)
    context.app.wait_for_text("Gerber - DevOps Multitool")
    context.app.wait_for_prompt()
    context.app.expect_input("/")
    context.app.expect_selected_suggestion("/exit")


@scenario(
    "plugin-list-direct-invocation-navigation",
    title="Direct /plugins list keeps shared parent navigation",
    categories=("plugin", "core", "escape", "navigation"),
    metadata=ScenarioMetadata(
        commands=("plugins list",),
        workflows=("command:plugins list", "navigation:direct-invocation"),
        coverage=("workflow", "navigation", "rendering"),
    ),
)
def plugin_list_direct_invocation_navigation(context) -> None:
    _start_plugin_management_session(context)
    context.app.type("/plugins list")
    context.app.press("ENTER")
    context.app.wait_for_text("/plugins list")
    context.app.wait_for_text(PLUGIN_GUID)
    context.app.press("ESCAPE")
    _expect_plugins_parent_menu(context)
    _return_to_root_from_plugins_parent(context)


@scenario(
    "plugin-management-info-recovery",
    title="Core plugin info recovery",
    categories=("plugin", "core", "errors", "recovery"),
    metadata=ScenarioMetadata(
        commands=("plugins info",),
        workflows=("command:plugins info", "plugin-management:invalid-guid"),
        coverage=("error-recovery",),
    ),
)
def plugin_management_info_recovery(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/plugins info 11111111-2222-not-a-guid")
    context.app.press("ENTER")
    context.app.wait_for_text("is not a valid GUID")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
