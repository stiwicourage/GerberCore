from __future__ import annotations

from typing import Any

import json

from .core_mission_support import ADO_PAT, assert_http_request, strict_http_fixture


COLLECTION_URI = "https://dev.azure.com/terminal/"
PROJECT_URI = f"{COLLECTION_URI}TerminalProject/"
PROJECT_ID = "project-terminal"
TEMPLATE_REPOSITORY_ID = "template-repo"
CREATED_REPOSITORY_ID = "created-repo"
TEAM_ID = "team-core"
REPOSITORY_NAME = "terminal-created"
DEFAULT_BRANCH = "refs/heads/main"
DEVELOP_BRANCH = "refs/heads/develop"
PIPELINE_PATH = "/pipelines/ci.yml"
PIPELINE_ID = 71
TEMPLATE_PIPELINE_ID = 41
REQUIRED_REVIEWER_TYPE_ID = "fd2167ab-b0be-447a-8ec8-39368250530e"
MINIMUM_REVIEWER_TYPE_ID = "fa4e907d-c16b-4a4c-9dfa-4906e5d171dd"
BUILD_VALIDATION_TYPE_ID = "0609b952-1397-4640-95ec-e00a01b2c241"
MAIN_COMMIT_ID = "1111111111111111111111111111111111111111"


def repository_create_success_fixture() -> dict[str, Any]:
    return strict_http_fixture(
        _selection_requests()
        + _successful_provisioning_requests()
        + _prompt_recovery_requests()
    )


def repository_create_failure_fixture() -> dict[str, Any]:
    return strict_http_fixture(
        _selection_requests()
        + [
            {
                "method": "Post",
                "uri": _repository_collection_uri(),
                "expectedBody": _repository_create_body(),
                "error": {
                    "type": "error",
                    "message": "Synthetic repository creation failure.",
                },
            }
        ]
        + _prompt_recovery_requests()
    )


def assert_repository_create_success_requests(request_list: list[dict[str, Any]]) -> None:
    expected_request_list = _selection_requests() + _successful_provisioning_requests() + _prompt_recovery_requests()
    assert len(request_list) == len(expected_request_list), request_list
    for request, expected in zip(request_list, expected_request_list, strict=True):
        assert_http_request(
            request,
            method=expected["method"],
            uri=expected["uri"],
            body=expected.get("expectedBody"),
        )
    assert request_list[5]["transport"] == "Invoke-WebRequest", request_list[5]
    assert request_list[6]["transport"] == "Invoke-WebRequest", request_list[6]


def assert_repository_create_failure_requests(request_list: list[dict[str, Any]]) -> None:
    expected_request_list = _selection_requests() + [
        {
            "method": "Post",
            "uri": _repository_collection_uri(),
            "expectedBody": _repository_create_body(),
        }
    ] + _prompt_recovery_requests()
    assert len(request_list) == len(expected_request_list), request_list
    for request, expected in zip(request_list, expected_request_list, strict=True):
        assert_http_request(
            request,
            method=expected["method"],
            uri=expected["uri"],
            body=expected.get("expectedBody"),
        )


def assert_repository_create_isolation(app) -> None:
    request_state = app.http_state()
    serialized_request_state = json.dumps(request_state)
    assert ADO_PAT not in serialized_request_state, request_state
    assert all(
        request["headers"].get("Authorization") == "<redacted>"
        for request in request_state["requests"]
    ), request_state

    credential_state = app.credential_state()
    assert credential_state["credentials"] == {"gerber:ado:terminal:pat": ADO_PAT}, credential_state
    assert credential_state["failures"] == {}, credential_state
    assert credential_state["operations"] == [
        {
            "operation": "Get",
            "service": "credentials",
            "account": "gerber:ado:terminal:pat",
        }
    ] * 6, credential_state

    scenario_root = app.runtime_paths.scenario_root
    config = json.loads((scenario_root / "config.json").read_text(encoding="utf-8-sig"))
    assert config["ado"]["profiles"]["terminal"]["projectUrl"] == PROJECT_URI.rstrip("/"), config
    assert (scenario_root / "home").is_dir(), scenario_root
    assert (scenario_root / "temp").is_dir(), scenario_root
    assert (scenario_root / "xdg-config").is_dir(), scenario_root


def _selection_requests() -> list[dict[str, Any]]:
    return [
        {
            "method": "Get",
            "uri": f"{COLLECTION_URI}_apis/projects?api-version=7.0",
            "response": {"value": [{"id": PROJECT_ID, "name": "TerminalProject"}]},
        },
        {
            "method": "Get",
            "uri": f"{PROJECT_URI}_apis/git/repositories?api-version=7.0",
            "response": {
                "value": [
                    {
                        "id": TEMPLATE_REPOSITORY_ID,
                        "name": "Template_Service",
                        "defaultBranch": DEFAULT_BRANCH,
                        "isDisabled": False,
                    }
                ]
            },
        },
        {
            "method": "Get",
            "uri": f"{COLLECTION_URI}_apis/projects/{PROJECT_ID}/teams?api-version=7.0",
            "response": {"value": [{"id": TEAM_ID, "name": "Core Team"}]},
        },
    ]


def _successful_provisioning_requests() -> list[dict[str, Any]]:
    return (
        _repository_content_requests()
        + _repository_branch_requests()
        + _repository_policy_requests()
    )


def _repository_content_requests() -> list[dict[str, Any]]:
    return [
        {
            "method": "Post",
            "uri": _repository_collection_uri(),
            "expectedBody": _repository_create_body(),
            "response": {"id": CREATED_REPOSITORY_ID},
        },
        {
            "method": "Get",
            "uri": _template_items_uri(),
            "response": {
                "value": [
                    {"path": "/README.md", "gitObjectType": "blob"},
                    {"path": PIPELINE_PATH, "gitObjectType": "blob"},
                ]
            },
        },
        {
            "method": "Get",
            "uri": _template_content_uri("/README.md"),
            "rawContent": "# PackageName\n",
        },
        {
            "method": "Get",
            "uri": _template_content_uri(PIPELINE_PATH),
            "rawContent": "name: PackageName\n",
        },
        {
            "method": "Post",
            "uri": f"{COLLECTION_URI}{PROJECT_ID}/_apis/git/repositories/{CREATED_REPOSITORY_ID}/pushes?api-version=7.0",
            "expectedBody": _initial_commit_body(),
            "response": {"pushId": 501},
        },
        {
            "method": "Post",
            "uri": f"{COLLECTION_URI}{PROJECT_ID}/_apis/pipelines?api-version=7.0",
            "expectedBody": _pipeline_create_body(),
            "response": {"id": PIPELINE_ID},
        },
    ]


def _repository_branch_requests() -> list[dict[str, Any]]:
    return [
        {
            "method": "Get",
            "uri": f"{COLLECTION_URI}{PROJECT_ID}/_apis/git/repositories/{TEMPLATE_REPOSITORY_ID}/refs?filter=heads%2F&api-version=7.0",
            "response": {"value": [{"name": DEFAULT_BRANCH}, {"name": DEVELOP_BRANCH}]},
        },
        {
            "method": "Get",
            "uri": f"{COLLECTION_URI}{PROJECT_ID}/_apis/git/repositories/{CREATED_REPOSITORY_ID}/refs?filter=heads%2Fmain&api-version=7.0",
            "response": {"value": [{"name": DEFAULT_BRANCH, "objectId": MAIN_COMMIT_ID}]},
        },
        {
            "method": "Post",
            "uri": f"{COLLECTION_URI}{PROJECT_ID}/_apis/git/repositories/{CREATED_REPOSITORY_ID}/refs?api-version=7.0",
            "expectedBody": [
                {
                    "name": DEVELOP_BRANCH,
                    "oldObjectId": "0000000000000000000000000000000000000000",
                    "newObjectId": MAIN_COMMIT_ID,
                }
            ],
            "response": {"value": [{"success": True}]},
        },
        {
            "method": "Patch",
            "uri": f"{COLLECTION_URI}{PROJECT_ID}/_apis/git/repositories/{CREATED_REPOSITORY_ID}?api-version=7.0",
            "expectedBody": {"defaultBranch": DEFAULT_BRANCH},
            "response": {"id": CREATED_REPOSITORY_ID, "defaultBranch": DEFAULT_BRANCH},
        },
    ]


def _repository_policy_requests() -> list[dict[str, Any]]:
    return [
        {
            "method": "Get",
            "uri": f"{COLLECTION_URI}{PROJECT_ID}/_apis/policy/configurations?api-version=7.0",
            "response": {"value": _template_policy_list()},
        },
        {
            "method": "Post",
            "uri": _policy_collection_uri(),
            "expectedBody": _minimum_reviewer_policy_body(),
            "response": {"id": 201},
        },
        {
            "method": "Get",
            "uri": f"{COLLECTION_URI}{PROJECT_ID}/_apis/pipelines/{TEMPLATE_PIPELINE_ID}?api-version=7.0",
            "response": {"configuration": {"path": PIPELINE_PATH}},
        },
        {
            "method": "Post",
            "uri": _policy_collection_uri(),
            "expectedBody": _build_validation_policy_body(),
            "response": {"id": 202},
        },
        {
            "method": "Get",
            "uri": f"{COLLECTION_URI}{PROJECT_ID}/_apis/git/repositories/{CREATED_REPOSITORY_ID}/refs?filter=heads%2F&api-version=7.0",
            "response": {"value": [{"name": DEFAULT_BRANCH}, {"name": DEVELOP_BRANCH}]},
        },
        {
            "method": "Post",
            "uri": _policy_collection_uri(),
            "expectedBody": _required_reviewer_policy_body(DEFAULT_BRANCH),
            "response": {"id": 203},
        },
        {
            "method": "Post",
            "uri": _policy_collection_uri(),
            "expectedBody": _required_reviewer_policy_body(DEVELOP_BRANCH),
            "response": {"id": 204},
        },
    ]


def _prompt_recovery_requests() -> list[dict[str, Any]]:
    return [_selection_requests()[1], _selection_requests()[0]]


def _repository_collection_uri() -> str:
    return f"{COLLECTION_URI}{PROJECT_ID}/_apis/git/repositories?api-version=7.0"


def _policy_collection_uri() -> str:
    return f"{COLLECTION_URI}{PROJECT_ID}/_apis/policy/configurations?api-version=7.0"


def _template_items_uri() -> str:
    return (
        f"{COLLECTION_URI}{PROJECT_ID}/_apis/git/repositories/{TEMPLATE_REPOSITORY_ID}/items"
        "?versionDescriptor.versionType=branch&versionDescriptor.version=main"
        "&recursionLevel=Full&api-version=7.0"
    )


def _template_content_uri(path: str) -> str:
    escaped_path = path.replace("/", "%2F")
    return (
        f"{COLLECTION_URI}{PROJECT_ID}/_apis/git/repositories/{TEMPLATE_REPOSITORY_ID}/items"
        f"?includeContent=true&path={escaped_path}&api-version=7.0"
    )


def _repository_create_body() -> dict[str, Any]:
    return {"name": REPOSITORY_NAME, "project": {"id": PROJECT_ID}}


def _initial_commit_body() -> dict[str, Any]:
    return {
        "refUpdates": [
            {
                "name": DEFAULT_BRANCH,
                "oldObjectId": "0000000000000000000000000000000000000000",
            }
        ],
        "commits": [
            {
                "comment": "Initial commit",
                "changes": [
                    _commit_change("/README.md", f"# {REPOSITORY_NAME}\n"),
                    _commit_change(PIPELINE_PATH, f"name: {REPOSITORY_NAME}\n"),
                ],
            }
        ],
    }


def _commit_change(path: str, content: str) -> dict[str, Any]:
    return {
        "changeType": "add",
        "item": {"path": path},
        "newContent": {"content": content, "contentType": "rawtext"},
    }


def _pipeline_create_body() -> dict[str, Any]:
    return {
        "name": f"{REPOSITORY_NAME} (ci)",
        "folder": "\\",
        "configuration": {
            "type": "yaml",
            "path": PIPELINE_PATH,
            "repository": {
                "id": CREATED_REPOSITORY_ID,
                "name": REPOSITORY_NAME,
                "type": "azureReposGit",
                "defaultBranch": DEFAULT_BRANCH,
            },
        },
    }


def _template_policy_list() -> list[dict[str, Any]]:
    scope = [{"repositoryId": TEMPLATE_REPOSITORY_ID, "refName": DEFAULT_BRANCH, "matchKind": "Exact"}]
    return [
        {
            "id": 11,
            "type": {"id": MINIMUM_REVIEWER_TYPE_ID},
            "settings": {"minimumApproverCount": 2, "scope": scope},
        },
        {
            "id": 12,
            "type": {"id": BUILD_VALIDATION_TYPE_ID},
            "settings": {
                "buildDefinitionId": TEMPLATE_PIPELINE_ID,
                "displayName": "Template_Service CI",
                "scope": scope,
            },
        },
        {
            "id": 13,
            "type": {"id": REQUIRED_REVIEWER_TYPE_ID},
            "settings": {"requiredReviewerIds": ["template-team"], "scope": scope},
        },
    ]


def _minimum_reviewer_policy_body() -> dict[str, Any]:
    return {
        "isEnabled": True,
        "isBlocking": True,
        "type": {"id": MINIMUM_REVIEWER_TYPE_ID},
        "settings": {
            "minimumApproverCount": 2,
            "scope": [_policy_scope(DEFAULT_BRANCH)],
        },
    }


def _build_validation_policy_body() -> dict[str, Any]:
    return {
        "isEnabled": True,
        "isBlocking": True,
        "type": {"id": BUILD_VALIDATION_TYPE_ID},
        "settings": {
            "buildDefinitionId": PIPELINE_ID,
            "displayName": f"{REPOSITORY_NAME} CI",
            "scope": [_policy_scope(DEFAULT_BRANCH)],
        },
    }


def _required_reviewer_policy_body(branch_ref: str) -> dict[str, Any]:
    return {
        "isEnabled": True,
        "isBlocking": True,
        "type": {"id": REQUIRED_REVIEWER_TYPE_ID},
        "settings": {
            "scope": [_policy_scope(branch_ref)],
            "requiredReviewerIds": [TEAM_ID],
        },
    }


def _policy_scope(branch_ref: str) -> dict[str, str]:
    return {
        "repositoryId": CREATED_REPOSITORY_ID,
        "refName": branch_ref,
        "matchKind": "Exact",
    }
