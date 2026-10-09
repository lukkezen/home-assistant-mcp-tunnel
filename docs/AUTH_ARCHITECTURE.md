# Generic MCP authentication architecture (proposal)

## Current implementation
The Home Assistant add-on launches one official OpenAI tunnel-client per configured MCP endpoint. The runtime API key authenticates the tunnel to the OpenAI control plane; it is NOT an OAuth identity for ChatGPT users. Upstream MCP credentials are configured independently using none, bearer or API-key headers.

## Security invariant
Never expose a credential-free file-processing endpoint to arbitrary callers merely because it is reached through a tunnel. Confirm the external tunnel's actual authentication guarantees before enabling it.

## Modes (target architecture; not implemented)
- **upstream_passthrough**: preserve upstream OAuth challenge, discovery metadata, redirects and authorization semantics end-to-end. Requires verified support in the official tunnel-client; static headers alone are insufficient.
- **gateway**: an authenticated authorization gateway validates client tokens (issuer, audience, expiry, scopes and allowed principals) on every MCP request before forwarding to an upstream server that may use independent static credentials. OAuth discovery, login and callback endpoints must be reachable through a supported public entrypoint. Never claim the runtime API key authenticates end users.
- **private**: for explicitly trusted network paths only; never expose unauthenticated upstreams to public callers.

## Design principles
1. Keep the tunnel generic: per-connection external auth and upstream auth are separate concerns.
2. Preserve current none/bearer/api_key upstream settings and behavior by default.
3. Fail closed for protected connections; do not silently downgrade to no authentication.
4. Bind tokens to the intended resource and audience; reject expired or untrusted tokens.
5. Keep refresh/access tokens out of logs and world-readable files.
6. Restrict file paths, sizes, operations and rate at the upstream application as defense in depth.
7. Avoid building an OAuth authorization server inside Bash. Prefer a maintained identity provider and a separately testable gateway if upstream tunnel support permits.
8. Verify capabilities of the pinned official tunnel-client release before implementation; this repository currently wraps that binary rather than implementing HTTP routing itself.

## Implementation gates
- Determine how OpenAI tunnel-client forwards HTTP 401, WWW-Authenticate, OAuth discovery endpoints and redirects.
- Confirm external client identity enforcement offered by the OpenAI tunnel control plane.
- Decide whether OAuth termination is possible at the local MCP endpoint or requires a separately hosted authorization endpoint.
- Add automated positive/negative tests (missing token, wrong audience, expired token, scope mismatch, valid user, direct upstream bypass).
- Introduce explicit opt-in settings and migration documentation, then ship behind a new release.

No authentication implementation is included in this proposal.
