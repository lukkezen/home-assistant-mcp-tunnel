# Changelog

## 0.1.4

- Add generic MCP Tunnel Manager branding for Home Assistant.
- Replace the previous add-on icon and logo with the new tunnel/network artwork.
- Keep branding provider-neutral so future tunnel providers can be added without changing the add-on identity.

## 0.1.3

- Fix Bearer and API-key authentication forwarding to MCP servers.
- Send MCP auth as direct static headers in `MCP_EXTRA_HEADERS` and discovery headers.
- Keep the OpenAI Runtime API Key file-backed.
- Restore the known-working `Authorization: Bearer <token>` behavior used by Postgram.

## 0.1.2

- Make MCP authentication migration-safe for existing tunnel entries.
- Put `bearer` first in the authentication selector.
- Treat a configured MCP token without an explicit auth type as Bearer authentication.
- Keep legacy `mcp_headers` temporarily supported so existing configurations continue to work.
- Add clear Home Assistant field labels and descriptions for nested tunnel settings.

## 0.1.1

- Add first-class MCP authentication settings.
- Add `bearer`, `api_key`, and `none` authentication modes.
- Add password-protected `mcp_api_key` field.
- Add configurable API-key header name.
- Keep optional custom and discovery headers for advanced use.
- Pass generated MCP credentials to the tunnel client through secret files.

## 0.1.0

- Initial Home Assistant release.
- Support multiple independently supervised OpenAI Secure MCP Tunnels.
- Per-tunnel MCP URL, headers, discovery headers, runtime key, and log level.
- Automatic restart of an individual tunnel process after unexpected exit.
