from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Iterable


@dataclass(frozen=True)
class ScenarioDefinition:
    id: str
    title: str
    categories: tuple[str, ...]
    commands: tuple[str, ...]
    workflows: tuple[str, ...]
    coverage: tuple[str, ...]
    viewport: tuple[int, int]
    run: Callable[["ScenarioContext"], None]


SCENARIO_REGISTRY: list[ScenarioDefinition] = []


@dataclass(frozen=True)
class ScenarioMetadata:
    commands: tuple[str, ...] = ()
    workflows: tuple[str, ...] = ()
    coverage: tuple[str, ...] = ()
    viewport: tuple[int, int] = (120, 40)


def scenario(
    scenario_id: str,
    *,
    title: str,
    categories: Iterable[str],
    metadata: ScenarioMetadata = ScenarioMetadata(),
) -> Callable[[Callable[["ScenarioContext"], None]], Callable[["ScenarioContext"], None]]:
    def decorator(func: Callable[["ScenarioContext"], None]) -> Callable[["ScenarioContext"], None]:
        if any(item.id == scenario_id for item in SCENARIO_REGISTRY):
            raise ValueError(f"Duplicate terminal scenario identifier '{scenario_id}'.")
        SCENARIO_REGISTRY.append(
            ScenarioDefinition(
                id=scenario_id,
                title=title,
                categories=tuple(categories),
                commands=metadata.commands,
                workflows=metadata.workflows,
                coverage=metadata.coverage,
                viewport=metadata.viewport,
                run=func,
            )
        )
        return func

    return decorator


# Imported lazily for type checking only.
class ScenarioContext:  # pragma: no cover - typing shim
    pass
