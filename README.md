<p align="center">
  <img src="mcp-tunnel/logo.png" alt="Home Assistant MCP Tunnel" width="250">
</p>

# Home Assistant MCP Tunnel

A Home Assistant add-on for running and managing multiple MCP tunnel clients.

The add-on uses provider-neutral tunnel/network branding. The first supported
tunnel provider is the official
[OpenAI Secure MCP Tunnel](https://github.com/openai/tunnel-client).

## Goals

- Run multiple tunnels from one Home Assistant add-on.
- Keep each tunnel independent: its own tunnel ID, runtime API key, MCP target,
  headers, discovery headers, and log level.
- Use the official upstream tunnel client without patching it.
- Stay independent of any specific MCP server such as Postgram or MCPHub.
- Keep the repository generic enough to add other tunnel providers later.

## Current provider

### OpenAI

Each configured tunnel starts one official `tunnel-client` process. If one
process exits unexpectedly, the add-on restarts that tunnel without stopping
the other configured tunnels.

See [the add-on documentation](mcp-tunnel/DOCS.md) for configuration examples.
