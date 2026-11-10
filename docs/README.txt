Gerber Core documentation

index.html is the authoritative static website source for gerber.ps.
Open it in a browser; assets are local. Preserve CNAME, CSS and the existing
responsive presentation when editing content.

The terminal preview illustrates Core's registry: /exit, /help, /plugins,
/update, /secrets and /tools. Its brand colors are illustrative; the real
session inherits the user's terminal colors. Plugin commands are not Core commands.

User guides: core-updates.md and credential-store-verification.md.
Plugin author guide: plugins-create.md.
Maintainer and public Plugin API references: architecture/*.md.
PowerShell help source: Gerber/en-US/*.md, consumed by Nova/PlatyPS.

Keep interactive slash-command syntax distinct from PowerShell installation,
launch and plugin-development cmdlets. The site has no command-surface selector.
Check edited links and anchors, PlatyPS help structure where affected, and
tests/TextFileFormatting.Tests.ps1. No site generator or site build is configured.
