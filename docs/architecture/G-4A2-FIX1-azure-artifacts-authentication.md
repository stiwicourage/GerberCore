# Plugin repository authentication reference

Audience: plugin authors and Core maintainers. Core contains no product-specific
authentication workflow.

## Repository identity

A plugin's installed manifest declares `PrivateData.Gerber.Repository` with a
display `Name` and canonical `Uri`. Gerber reads the installed file, displays
the name and passes the URI to PMU. The canonical descriptor wins over legacy
`RepositoryUri`. Missing metadata defaults to PSGallery; invalid explicit
metadata never falls back.

URIs must be absolute and contain no credentials, query or fragment. A repository
name is a label, not evidence that an endpoint is trusted or reachable.
Generated placeholders must be replaced and the plugin rebuilt before updates.

## Credentials and consent

Manual plugin updates can request repository credentials through Gerber's
text/secure-input patterns for that operation only. They are not written to
plugin metadata, update plans on disk, traces or native credential storage.
Noninteractive update views do not request credentials or install.

Selecting a plugin candidate permits a temporary package download for manifest
inspection. Required trust/license acceptance is operation-local. Final
installation still requires the separate default-Cancel confirmation.

Core itself always uses public PSGallery and never requests repository
credentials. Plugin settings cannot change Core's source.

See [plugin repository policy](../core-updates.md#plugin-repositories) and
[the PMU boundary](G-4A1-psmoduleupdate-design.md). This page describes the generic
contract, not proof of live authentication against any particular private feed.
