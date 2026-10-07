# MCP Tunnel Manager

MCP Tunnel Manager runs multiple MCP tunnel clients from one Home Assistant
add-on.

## Supported providers

Currently supported:

- `openai` - OpenAI Secure MCP Tunnel using the official
  `openai/tunnel-client` runtime.

The add-on is intentionally not tied to Postgram, MCPHub, or another specific
MCP server.

## Configuration

The add-on configuration contains a list called `tunnels`.

### Bearer token example

This is the normal choice for Postgram and other MCP servers that authenticate
with `Authorization: Bearer ...`.

```yaml
tunnels:
  - name: postgram
    enabled: true
    provider: openai
    tunnel_id: tunnel_0123456789abcdef0123456789abcdef
    runtime_api_key: sk-example
    mcp_server_url: http://192.168.1.10:3100/mcp
    mcp_auth_type: bearer
    mcp_api_key: pgm-example-token
    mcp_api_key_header: X-API-Key
    custom_headers: ""
    discovery_headers: ""
    log_level: info
```

The manager automatically turns that into an `Authorization: Bearer ...`
header. You do not have to type the header yourself.

### API key header example

For an MCP server that expects `X-API-Key: ...`:

```yaml
tunnels:
  - name: todo
    enabled: true
    provider: openai
    tunnel_id: tunnel_fedcba9876543210fedcba9876543210
    runtime_api_key: sk-example-2
    mcp_server_url: http://192.168.1.20:3000/mcp
    mcp_auth_type: api_key
    mcp_api_key: my-secret-api-key
    mcp_api_key_header: X-API-Key
    custom_headers: ""
    discovery_headers: ""
    log_level: info
```

### No authentication

For an MCP endpoint that needs no authentication:

```yaml
mcp_auth_type: none
mcp_api_key: ""
```

## Tunnel options

| Option | Required | Description |
| --- | --- | --- |
| `name` | yes | Human-readable local name used in logs |
| `enabled` | yes | Start or skip this tunnel |
| `provider` | yes | Currently only `openai` |
| `tunnel_id` | yes | OpenAI tunnel ID |
| `runtime_api_key` | yes | OpenAI Runtime API Key for the tunnel |
| `mcp_server_url` | yes | Streamable HTTP MCP endpoint |
| `mcp_auth_type` | yes | `none`, `bearer`, or `api_key` |
| `mcp_api_key` | bearer/api_key | MCP server token or API key; shown as a password field |
| `mcp_api_key_header` | api_key | Header name for API-key auth, normally `X-API-Key` |
| `custom_headers` | no | Optional additional static headers |
| `discovery_headers` | no | Optional override for discovery/probing headers |
| `log_level` | yes | `debug`, `info`, or `warn` |

## Authentication behavior

### `bearer`

The value in `mcp_api_key` becomes:

```text
Authorization: Bearer <mcp_api_key>
```

### `api_key`

The value is sent in the header named by `mcp_api_key_header`.

With:

```yaml
mcp_api_key_header: X-API-Key
mcp_api_key: secret
```

the MCP server receives:

```text
X-API-Key: secret
```

### `custom_headers`

Use this only for additional or unusual static headers. Multiple headers use
the tunnel client's comma-separated format:

```text
X-Tenant: home, X-Environment: production
```

The generated authentication header and `custom_headers` are combined.

If `discovery_headers` is empty, the same resulting headers are automatically
used for MCP discovery and startup probing.

## Security

The OpenAI Runtime API Key is written to a per-tunnel file under
`/data/secrets` with restrictive permissions and passed to the tunnel client
using a `file:` reference.

MCP authentication is supplied through `MCP_EXTRA_HEADERS` and
`MCP_DISCOVERY_EXTRA_HEADERS`. For Bearer authentication this is sent as
`Authorization: Bearer <token>`, matching the known-working Postgram setup.

Home Assistant stores configured credentials in the add-on options, so Home
Assistant backups should be treated as sensitive.

## Process model

One configured tunnel equals one independent `tunnel-client` process.

```text
Home Assistant
└── MCP Tunnel Manager
    ├── tunnel-client: postgram -> MCP server A
    ├── tunnel-client: todo     -> MCP server B
    └── tunnel-client: other    -> MCP server C
```

If one tunnel exits, its supervisor waits five seconds and restarts only that
tunnel. Other tunnels keep running.
