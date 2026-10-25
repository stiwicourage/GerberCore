from __future__ import annotations

import json

from framework.scenario_registry import ScenarioMetadata, scenario

from .core_mission_support import (
    ADO_PAT,
    assert_http_request,
    assert_no_secret_leak,
    replace_secret_name_template,
    seed_ado_state,
    seed_credential_state,
    start_with_credentials,
    strict_http_fixture,
    verify_secret_creation,
    verify_secret_hidden_reveal,
    verify_secret_inventory,
    verify_secret_presence,
    verify_secret_removal,
)
from .repository_create_support import (
    REPOSITORY_NAME,
    assert_repository_create_failure_requests,
    assert_repository_create_isolation,
    assert_repository_create_success_requests,
    repository_create_failure_fixture,
    repository_create_success_fixture,
)


COLLECTION_URI = "https://dev.azure.com/terminal/"
PROJECT_URI = f"{COLLECTION_URI}TerminalProject/"


def _start_ado_scenario(context, fixture: dict) -> None:
    seed_ado_state(context)
    context.app.start(http_fixture=fixture)
    context.app.wait_for_prompt()


def _cancel_command_at_prompt(context, command: str, prompt_text: str) -> None:
    _start_ado_scenario(context, strict_http_fixture([]))
    context.app.type(f"/{command}")
    context.app.press("ENTER")
    context.app.wait_for_text(prompt_text)
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    assert context.app.http_state()["requests"] == []
    assert_no_secret_leak(context.app, ADO_PAT)


def _agent_fixture() -> dict:
    return strict_http_fixture(
        [
            {
                "method": "Get",
                "uri": f"{COLLECTION_URI}_apis/distributedtask/pools?api-version=7.1&poolType=automation",
                "response": {"value": [{"id": 11, "name": "Build Pool"}]},
            },
            {
                "method": "Get",
                "uri": f"{COLLECTION_URI}_apis/distributedtask/pools?poolType=automation&api-version=7.1",
                "response": {"value": [{"id": 11, "name": "Build Pool"}]},
            },
            {
                "method": "Get",
                "uri": f"{COLLECTION_URI}_apis/distributedtask/pools/11/agents?api-version=7.1&includeCapabilities=false",
                "response": {"value": [{"name": "build-01", "version": "4.255.0", "status": "online"}]},
            },
            {
                "method": "Get",
                "uri": f"{COLLECTION_URI}_apis/distributedtask/pools/11/agents?includeCapabilities=false&api-version=7.1",
                "response": {"value": [{"name": "build-01", "version": "4.255.0", "status": "online"}]},
            },
            {
                "method": "Get",
                "uri": f"{COLLECTION_URI}_apis/distributedtask/pools?api-version=7.1&poolType=deployment",
                "response": {"value": [{"id": 22, "name": "Deploy Pool"}]},
            },
            {
                "method": "Get",
                "uri": f"{COLLECTION_URI}_apis/distributedtask/pools?poolType=deployment&api-version=7.1",
                "response": {"value": [{"id": 22, "name": "Deploy Pool"}]},
            },
            {
                "method": "Get",
                "uri": f"{COLLECTION_URI}_apis/distributedtask/pools/22/agents?api-version=7.1&includeCapabilities=false",
                "response": {"value": [{"name": "deploy-01", "version": "4.255.0", "status": "online"}]},
            },
            {
                "method": "Get",
                "uri": f"{COLLECTION_URI}_apis/distributedtask/pools/22/agents?includeCapabilities=false&api-version=7.1",
                "response": {"value": [{"name": "deploy-01", "version": "4.255.0", "status": "online"}]},
            },
        ]
    )


def _team_fixture() -> dict:
    return strict_http_fixture(
        [
            {
                "method": "Get",
                "uri": f"{COLLECTION_URI}_apis/projects?api-version=7.0",
                "response": {"value": [{"id": "project-terminal", "name": "TerminalProject"}]},
            },
            {
                "method": "Get",
                "uri": f"{COLLECTION_URI}_apis/projects/project-terminal/teams?api-version=7.0",
                "response": {"value": [{"id": "team-core", "name": "Core Team"}]},
            },
            {
                "method": "Get",
                "uri": f"{COLLECTION_URI}_apis/projects/project-terminal/teams/team-core/members?api-version=7.0",
                "response": {
                    "value": [
                        {
                            "displayName": "Core Developer",
                            "uniqueName": "core@example.test",
                        }
                    ]
                },
            },
        ]
    )


def _branch_find_fixture() -> dict:
    return strict_http_fixture(
        [
            {
                "method": "Get",
                "uri": f"{PROJECT_URI}_apis/git/repositories?api-version=7.0",
                "response": {
                    "value": [
                        {
                            "id": "repo-a",
                            "name": "Repository A",
                            "defaultBranch": "refs/heads/main",
                            "isDisabled": False,
                        },
                        {
                            "id": "repo-b",
                            "name": "Repository B",
                            "defaultBranch": "refs/heads/develop",
                            "isDisabled": False,
                        },
                    ]
                },
            },
            {
                "method": "Get",
                "uri": f"{PROJECT_URI}_apis/git/repositories/repo-a/refs?api-version=7.0&filter=heads%2Fmain",
                "response": {
                    "value": [
                        {
                            "name": "refs/heads/main",
                            "isDisabled": False,
                        }
                    ]
                },
            },
            {
                "method": "Get",
                "uri": f"{PROJECT_URI}_apis/git/repositories/repo-a/refs?filter=heads%2Fmain&api-version=7.0",
                "response": {
                    "value": [
                        {
                            "name": "refs/heads/main",
                            "isDisabled": False,
                        }
                    ]
                },
            },
            {
                "method": "Get",
                "uri": f"{PROJECT_URI}_apis/git/repositories/repo-b/refs?api-version=7.0&filter=heads%2Fmain",
                "response": {"value": []},
            },
            {
                "method": "Get",
                "uri": f"{PROJECT_URI}_apis/git/repositories/repo-b/refs?filter=heads%2Fmain&api-version=7.0",
                "response": {"value": []},
            },
        ]
    )


def _repository_list_response() -> dict:
    return {
        "value": [
            {
                "id": "repo-a",
                "name": "Repository A",
                "defaultBranch": "refs/heads/develop",
                "isDisabled": False,
            },
            {
                "id": "repo-b",
                "name": "Repository B",
                "defaultBranch": "refs/heads/main",
                "isDisabled": False,
            },
        ]
    }


def _branch_set_default_fixture() -> dict:
    return strict_http_fixture(
        [
            {
                "method": "Get",
                "uri": f"{PROJECT_URI}_apis/git/repositories?api-version=7.0",
                "response": _repository_list_response(),
            },
            {
                "method": "Get",
                "uri": f"{PROJECT_URI}_apis/git/repositories/repo-a/refs?api-version=7.0&filter=heads%2Fmain",
                "response": {"value": [{"name": "refs/heads/main"}]},
            },
            {
                "method": "Get",
                "uri": f"{PROJECT_URI}_apis/git/repositories/repo-a/refs?filter=heads%2Fmain&api-version=7.0",
                "response": {"value": [{"name": "refs/heads/main"}]},
            },
            {
                "method": "Patch",
                "uri": f"{PROJECT_URI}_apis/git/repositories/repo-a?api-version=7.0",
                "response": {"id": "repo-a", "defaultBranch": "refs/heads/main"},
            },
        ]
    )


def _branch_set_searchable_fixture() -> dict:
    policy_type = "0517f88d-4ec5-4343-9d26-9930ebd53069"
    return strict_http_fixture(
        [
            {
                "method": "Get",
                "uri": f"{PROJECT_URI}_apis/git/repositories?api-version=7.0",
                "response": {
                    "value": [
                        {
                            "id": "repo-a",
                            "name": "Repository A",
                            "defaultBranch": "refs/heads/develop",
                            "isDisabled": False,
                        }
                    ]
                },
            },
            {
                "method": "Get",
                "uri": (
                    f"{PROJECT_URI}_apis/policy/configurations"
                    f"?policyType={policy_type}&api-version=7.0"
                ),
                "response": {"value": []},
            },
            {
                "method": "Post",
                "uri": f"{PROJECT_URI}_apis/policy/configurations?api-version=7.0",
                "response": {"id": 42},
            },
        ]
    )


def _tagged_build_response() -> dict:
    return {
        "value": [
            {
                "id": 1001,
                "buildNumber": "2026.01",
                "queueTime": "2026-06-19T09:00:00Z",
                "status": "completed",
                "result": "succeeded",
                "definition": {"id": 7, "name": "Pipeline A"},
            }
        ]
    }


def _pipeline_tag_fixture(*, update: bool) -> dict:
    request_list = [
        {
            "method": "Get",
            "uri": (
                f"{PROJECT_URI}_apis/build/builds"
                "?%24top=200&tagFilters=old&api-version=7.1&queryOrder=queueTimeDescending"
            ),
            "response": _tagged_build_response(),
        },
        {
            "method": "Get",
            "uri": (
                f"{PROJECT_URI}_apis/build/builds"
                "?api-version=7.1&tagFilters=old&%24top=200&queryOrder=queueTimeDescending"
            ),
            "response": _tagged_build_response(),
        },
        {
            "method": "Delete",
            "uri": f"{PROJECT_URI}_apis/build/builds/1001/tags/old?api-version=7.1",
            "response": {},
        },
    ]
    if update:
        request_list.append(
            {
                "method": "Put",
                "uri": f"{PROJECT_URI}_apis/build/builds/1001/tags/new?api-version=7.1",
                "response": {},
            }
        )
    return strict_http_fixture(request_list)


def _select_action_confirmation(context, *, default_cancel: bool = False) -> None:
    context.app.wait_for_text("Confirm")
    if default_cancel:
        context.app.press("DOWN")
    context.app.press("ENTER")


@scenario(
    "core-mission-ado-agents-success",
    title="Core ADO agent report",
    categories=("core", "mission", "ado"),
    metadata=ScenarioMetadata(
        commands=("list ado-agents",),
        workflows=("command:list ado-agents",),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def ado_agents_success(context) -> None:
    _start_ado_scenario(context, _agent_fixture())
    context.app.type("/list ado-agents")
    context.app.press("ENTER")
    context.app.wait_for_text("Build Pool")
    context.app.wait_for_text("deploy-01")
    request_list = context.app.http_state()["requests"]
    assert len(request_list) == 4, request_list
    assert_no_secret_leak(context.app, ADO_PAT)


@scenario(
    "core-mission-ado-agents-recovery",
    title="Core ADO agent report recovery",
    categories=("core", "mission", "ado", "recovery"),
    metadata=ScenarioMetadata(
        commands=("list ado-agents",),
        workflows=("command:list ado-agents", "network:controlled-failure"),
        coverage=("error-recovery",),
    ),
)
def ado_agents_recovery(context) -> None:
    _start_ado_scenario(context, strict_http_fixture([]))
    context.app.type("/list ado-agents")
    context.app.press("ENTER")
    context.app.wait_for_text("Unexpected Gerber Core terminal HTTP request.")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    assert_no_secret_leak(context.app, ADO_PAT)


@scenario(
    "core-mission-ado-team-members",
    title="Core ADO team member selection",
    categories=("core", "mission", "ado", "selection"),
    metadata=ScenarioMetadata(
        commands=("list ado-team-members",),
        workflows=("command:list ado-team-members",),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def ado_team_members(context) -> None:
    _start_ado_scenario(context, _team_fixture())
    context.app.type("/list ado-team-members")
    context.app.press("ENTER")
    context.app.wait_for_text("Export or continue")
    context.app.press("ENTER")
    context.app.wait_for_text("Select project (Esc to go back)")
    context.app.press("ENTER")
    context.app.wait_for_text("Select team (Esc to go back)")
    context.app.press("ENTER")
    context.app.wait_for_text("Core Developer (core@example.test)")
    assert_no_secret_leak(context.app, ADO_PAT)


@scenario(
    "core-mission-ado-team-members-recovery",
    title="Core ADO team member recovery",
    categories=("core", "mission", "ado", "recovery"),
    metadata=ScenarioMetadata(
        commands=("list ado-team-members",),
        workflows=("command:list ado-team-members", "network:controlled-failure"),
        coverage=("error-recovery",),
    ),
)
def ado_team_members_recovery(context) -> None:
    _start_ado_scenario(context, strict_http_fixture([]))
    context.app.type("/list ado-team-members")
    context.app.press("ENTER")
    context.app.wait_for_text("could not read Azure DevOps projects")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    assert_no_secret_leak(context.app, ADO_PAT)


@scenario(
    "core-mission-branch-find",
    title="Core branch search",
    categories=("core", "mission", "ado"),
    metadata=ScenarioMetadata(
        commands=("branch find",),
        workflows=("command:branch find",),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def branch_find(context) -> None:
    _start_ado_scenario(context, _branch_find_fixture())
    context.app.type("/branch find")
    context.app.press("ENTER")
    context.app.wait_for_text("Branch path")
    context.app.type("main")
    context.app.press("ENTER")
    context.app.wait_for_text("Repository A")
    context.app.wait_for_text("Found in 1 of 2 repositories.")
    assert_http_request(
        context.app.http_state()["requests"][0],
        method="Get",
        uri=f"{PROJECT_URI}_apis/git/repositories?api-version=7.0",
    )
    assert_no_secret_leak(context.app, ADO_PAT)


def _run_ado_failure_recovery(
    context,
    command: str,
    input_list: list[tuple[str, str]],
    expected_text: str = "Unexpected Gerber Core terminal HTTP request.",
) -> None:
    _start_ado_scenario(context, strict_http_fixture([]))
    context.app.type(f"/{command}")
    context.app.press("ENTER")
    for prompt_text, value in input_list:
        context.app.wait_for_text(prompt_text)
        context.app.type(value)
        context.app.press("ENTER")
    context.app.wait_for_text(expected_text)
    context.app.press("ENTER")
    assert_no_secret_leak(context.app, ADO_PAT)


@scenario(
    "core-mission-branch-failure-recovery",
    title="Core branch workflow failure recovery",
    categories=("core", "mission", "ado", "recovery"),
    metadata=ScenarioMetadata(
        commands=("branch find", "branch set-default", "branch set-searchable"),
        workflows=("network:controlled-failure",),
        coverage=("error-recovery",),
    ),
)
def branch_failure_recovery(context) -> None:
    _run_ado_failure_recovery(context, "branch find", [("Branch path", "main")])
    context.app.close()
    _run_ado_failure_recovery(context, "branch set-default", [("Branch name", "main")])
    context.app.close()
    _run_ado_failure_recovery(
        context,
        "branch set-searchable",
        [("Branch names", "main"), ("Mode", "")],
    )


@scenario(
    "core-mission-pipeline-tag-failure-recovery",
    title="Core pipeline tag workflow failure recovery",
    categories=("core", "mission", "ado", "recovery"),
    metadata=ScenarioMetadata(
        commands=("pipelines tags delete", "pipelines tags update"),
        workflows=("network:controlled-failure",),
        coverage=("error-recovery",),
    ),
)
def pipeline_tag_failure_recovery(context) -> None:
    _run_ado_failure_recovery(
        context,
        "pipelines tags delete",
        [("Current tag", "old")],
        "could not read Azure DevOps builds",
    )
    context.app.close()
    _run_ado_failure_recovery(
        context,
        "pipelines tags update",
        [("Current tag", "old"), ("New tag", "new")],
        "could not read Azure DevOps builds",
    )


def _register_cancel_scenario(
    scenario_id: str,
    command: str,
    prompt_text: str,
) -> None:
    @scenario(
        scenario_id,
        title=f"Core {command} deterministic cancellation",
        categories=("core", "mission", "cancellation"),
        metadata=ScenarioMetadata(
            commands=(command,),
            workflows=(f"command:{command}", f"cancel:{command}"),
            coverage=("dispatch", "navigation", "rendering"),
        ),
    )
    def cancel_scenario(context) -> None:
        _cancel_command_at_prompt(context, command, prompt_text)


@scenario(
    "core-mission-branch-set-default",
    title="Core branch default mutation",
    categories=("core", "mission", "ado", "mutation"),
    metadata=ScenarioMetadata(
        commands=("branch set-default",),
        workflows=("command:branch set-default", "mutation:default-branch"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def branch_set_default(context) -> None:
    _start_ado_scenario(context, _branch_set_default_fixture())
    context.app.type("/branch set-default")
    context.app.press("ENTER")
    context.app.wait_for_text("Branch name")
    context.app.type("main")
    context.app.press("ENTER")
    context.app.wait_for_text("To update (1)")
    context.app.wait_for_text("Repository A")
    _select_action_confirmation(context)
    context.app.wait_for_text("Updated 1")
    request_list = context.app.http_state()["requests"]
    assert_http_request(
        request_list[-1],
        method="Patch",
        uri=f"{PROJECT_URI}_apis/git/repositories/repo-a?api-version=7.0",
        body={"defaultBranch": "refs/heads/main"},
    )
    assert_no_secret_leak(context.app, ADO_PAT)


@scenario(
    "core-mission-branch-set-searchable",
    title="Core searchable branch policy mutation",
    categories=("core", "mission", "ado", "mutation"),
    metadata=ScenarioMetadata(
        commands=("branch set-searchable",),
        workflows=("command:branch set-searchable", "mutation:searchable-branch-policy"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def branch_set_searchable(context) -> None:
    _start_ado_scenario(context, _branch_set_searchable_fixture())
    context.app.type("/branch set-searchable")
    context.app.press("ENTER")
    context.app.wait_for_text("Branch names")
    context.app.type("main")
    context.app.press("ENTER")
    context.app.wait_for_text("Mode")
    context.app.press("ENTER")
    context.app.wait_for_text("To create (1)")
    _select_action_confirmation(context)
    context.app.wait_for_text("Created 1")
    request_list = context.app.http_state()["requests"]
    assert_http_request(
        request_list[-1],
        method="Post",
        uri=f"{PROJECT_URI}_apis/policy/configurations?api-version=7.0",
    )
    assert request_list[-1]["body"]["isEnabled"] is True, request_list[-1]
    assert request_list[-1]["body"]["isBlocking"] is False, request_list[-1]
    assert_no_secret_leak(context.app, ADO_PAT)


def _run_pipeline_tag_mutation(context, *, update: bool) -> None:
    command = "pipelines tags update" if update else "pipelines tags delete"
    _start_ado_scenario(context, _pipeline_tag_fixture(update=update))
    context.app.type(f"/{command}")
    context.app.press("ENTER")
    context.app.wait_for_text("Current tag")
    context.app.type("old")
    context.app.press("ENTER")
    if update:
        context.app.wait_for_text("New tag")
        context.app.type("new")
        context.app.press("ENTER")
    context.app.wait_for_text("Tagged runs")
    context.app.press("SPACE")
    context.app.press("SPACE")
    context.app.press("ENTER")
    _select_action_confirmation(context, default_cancel=True)
    expected_text = "Updated: 1" if update else "Deleted: 1"
    context.app.wait_for_text(expected_text)
    request_list = context.app.http_state()["requests"]
    expected_methods = ["Get", "Delete", "Put"] if update else ["Get", "Delete"]
    assert [item["method"] for item in request_list] == expected_methods, request_list
    assert_no_secret_leak(context.app, ADO_PAT)


@scenario(
    "core-mission-pipeline-tags-delete",
    title="Core pipeline tag delete mutation",
    categories=("core", "mission", "ado", "mutation"),
    metadata=ScenarioMetadata(
        commands=("pipelines tags delete",),
        workflows=("command:pipelines tags delete", "mutation:delete-build-tag"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def pipeline_tags_delete(context) -> None:
    _run_pipeline_tag_mutation(context, update=False)


@scenario(
    "core-mission-pipeline-tags-update",
    title="Core pipeline tag update mutation",
    categories=("core", "mission", "ado", "mutation"),
    metadata=ScenarioMetadata(
        commands=("pipelines tags update",),
        workflows=("command:pipelines tags update", "mutation:update-build-tag"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def pipeline_tags_update(context) -> None:
    _run_pipeline_tag_mutation(context, update=True)


@scenario(
    "core-mission-repository-create",
    title="Core repository create complete isolated provisioning",
    categories=("core", "mission", "ado", "mutation"),
    metadata=ScenarioMetadata(
        commands=("repository create",),
        workflows=(
            "command:repository create",
            "mutation:create-repository",
            "mutation:initial-commit",
            "mutation:create-pipeline",
            "mutation:create-branch",
            "mutation:set-default-branch",
            "mutation:copy-policies",
        ),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def repository_create(context) -> None:
    _run_repository_create_scenario(context, success=True)


@scenario(
    "core-mission-repository-create-recovery",
    title="Core repository create controlled failure recovery",
    categories=("core", "mission", "ado", "mutation", "recovery"),
    metadata=ScenarioMetadata(
        commands=("repository create",),
        workflows=(
            "command:repository create",
            "mutation:create-repository",
            "network:controlled-failure",
        ),
        coverage=("dispatch", "workflow", "navigation", "rendering", "error-recovery"),
    ),
)
def repository_create_recovery(context) -> None:
    _run_repository_create_scenario(context, success=False)


def _run_repository_create_scenario(
    context,
    *,
    success: bool,
) -> None:
    options = _repository_create_scenario_options(success)
    _start_ado_scenario(context, options["fixture"])
    _complete_repository_create_input(context)
    context.app.wait_for_text(options["result_text"])
    _recover_repository_create_prompt(context)
    options["request_assertion"](context.app.http_state()["requests"])
    assert_repository_create_isolation(context.app)
    _assert_repository_create_trace(context, success=options["success"])
    assert_no_secret_leak(context.app, ADO_PAT)


def _repository_create_scenario_options(success: bool) -> dict:
    if success:
        return {
            "fixture": repository_create_success_fixture(),
            "result_text": "Repository created successfully.",
            "success": True,
            "request_assertion": assert_repository_create_success_requests,
        }
    return {
        "fixture": repository_create_failure_fixture(),
        "result_text": "Synthetic repository creation failure.",
        "success": False,
        "request_assertion": assert_repository_create_failure_requests,
    }


def _complete_repository_create_input(context) -> None:
    context.app.type("/repository create")
    context.app.press("ENTER")
    context.app.wait_for_text("Project")
    context.app.wait_for_text("TerminalProject")
    context.app.press("ENTER")
    context.app.wait_for_text("Template")
    context.app.wait_for_text("Template_Service")
    context.app.press("ENTER")
    context.app.wait_for_text("Repository name")
    context.app.type(REPOSITORY_NAME)
    context.app.press("ENTER")
    context.app.wait_for_text("Owner team")
    context.app.wait_for_text("Core Team")
    context.app.press("ENTER")
    context.app.wait_for_text(f"Repository: {REPOSITORY_NAME}")
    context.app.wait_for_text("Template:   Template_Service")
    context.app.wait_for_text("Owner team: Core Team")
    _select_action_confirmation(context)


def _recover_repository_create_prompt(context) -> None:
    context.app.press("ENTER")
    context.app.wait_for_text("Template")
    context.app.press("ESCAPE")
    context.app.wait_for_text("Project")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()


def _assert_repository_create_trace(context, *, success: bool) -> None:
    event_map = {
        item["Event"]: item["Data"]
        for item in (
            json.loads(line)
            for line in context.app.prompt_trace_text().splitlines()
            if line.strip()
        )
    }
    assert event_map["create-repository-project-selected"]["ProjectName"] == "TerminalProject", event_map
    assert event_map["create-repository-template-selected"]["TemplateName"] == "Template_Service", event_map
    assert event_map["create-repository-name-entered"]["RepositoryName"] == REPOSITORY_NAME, event_map
    assert event_map["create-repository-team-selected"]["TeamName"] == "Core Team", event_map
    assert event_map["create-repository-confirmed"]["Confirmed"] is True, event_map
    assert event_map["create-repository-apply-done"]["Success"] is success, event_map
    assert "create-repository-result-shown" in event_map, event_map


@scenario(
    "core-mission-secrets-lifecycle",
    title="Core secrets isolated lifecycle",
    categories=("core", "mission", "credentials"),
    metadata=ScenarioMetadata(
        commands=(
            "secrets list",
            "secrets get",
            "secrets test",
            "secrets set",
            "secrets remove",
        ),
        workflows=(
            "command:secrets list",
            "command:secrets get",
            "command:secrets test",
            "command:secrets set",
            "command:secrets remove",
            "credentials:isolated-lifecycle",
        ),
        coverage=("dispatch", "workflow", "navigation", "rendering", "error-recovery"),
    ),
)
def secrets_lifecycle(context) -> None:
    identifier = "gerber:terminal:fixture"
    secret = "terminal-secret-value"
    context.app.register_sensitive_value(secret)
    verify_secret_inventory(context, identifier, secret)
    verify_secret_presence(context, identifier, secret)
    verify_secret_hidden_reveal(context, identifier, secret)
    verify_secret_creation(context, secret)
    verify_secret_removal(context, identifier, secret)


@scenario(
    "core-mission-secrets-storage-recovery",
    title="Core secrets controlled storage failure recovery",
    categories=("core", "mission", "credentials", "recovery"),
    metadata=ScenarioMetadata(
        commands=("secrets list", "secrets get", "secrets test", "secrets set", "secrets remove"),
        workflows=("credentials:controlled-storage-failure",),
        coverage=("error-recovery",),
    ),
)
def secrets_storage_recovery(context) -> None:
    secret = "terminal-never-render-this-secret"
    context.app.register_sensitive_value(secret)
    for command in ("secrets list", "secrets get", "secrets remove"):
        seed_credential_state(
            context.app.runtime_paths.credential_state_path,
            {"gerber:terminal:fixture": secret},
            {"GetAccounts": "Synthetic credential inventory failure."},
        )
        context.app.start(http_fixture=strict_http_fixture([]))
        context.app.wait_for_prompt()
        context.app.type(f"/{command}")
        context.app.press("ENTER")
        context.app.wait_for_text("secure credential storage is unavailable")
        context.app.expect_text_absent("Synthetic credential inventory failure.")
        context.app.press("ENTER")
        assert_no_secret_leak(context.app, secret)
        context.app.close()

    for command, prompt_text in (
        ("secrets test", "Gerber credential identifier"),
        ("secrets set", "Gerber secret name"),
    ):
        seed_credential_state(
            context.app.runtime_paths.credential_state_path,
            {},
            {"GetAccounts": "Synthetic credential read failure."},
        )
        context.app.start(http_fixture=strict_http_fixture([]))
        context.app.wait_for_prompt()
        context.app.type(f"/{command}")
        context.app.press("ENTER")
        context.app.wait_for_text(prompt_text)
        if command == "secrets set":
            replace_secret_name_template(context, "terminal:failure")
        else:
            context.app.type("gerber:terminal:failure")
            context.app.press("ENTER")
        context.app.wait_for_text("secure credential storage is unavailable")
        context.app.press("ENTER")
        assert_no_secret_leak(context.app, secret)
        context.app.close()

    start_with_credentials(context, {})
    assert_no_secret_leak(context.app, secret)
