---
applyTo: "tests/**/*.ps1"
---

# Plugin behavior tests

Follow [AGENTS.md](../../AGENTS.md). Add a source-mirrored unit test for each
changed handler/definition and use `tests/PluginTestSupport.ps1` for source loading.
Write/run changed-behavior tests red before implementation; characterize
unchanged behavior green before refactoring. Preserve output/error assertions.

Mock the supplied API operations rather than private Core implementation.
Cover namespace/menu routing, arguments, cancellation and recoverable failure.
Use `.Integration.Tests.ps1` for built-module identity/export/handler checks.
Run `Invoke-NovaTest` and `Test-NovaBuild`; do not bypass the 90% coverage gate,
use actual credentials, or publish into a user's module directory in tests.
