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

## Verified upstream capabilities (2026-10-09)
Current add-on Dockerfile pins `ghcr.io/openai/tunnel-client:v0.0.16`. Official tunnel-client documentation describes support for:
- Forwarding inbound Authorization to the MCP origin.
- Forwarding OAuth Protected Resource Metadata discovery and rewriting resource URLs to the tunnel-service URL.
- Discovering an upstream authorization server from PRMD and supporting token/registration/revocation shim routes where configured.
- **Not** exposing the browser-facing authorization endpoint automatically; it remains a direct browser-to-IdP URL.

References:
- https://github.com/openai/tunnel-client/blob/master/docs/configuration.md
- https://github.com/openai/tunnel-client/blob/master/docs/architecture.md
- https://github.com/openai/tunnel-client/blob/master/docs/onboarding.md

Implications:
1. Passthrough is already supported by the upstream tunnel client for a properly OAuth-protected MCP. No new passthrough code is justified yet.
2. A local upstream with `mcp_auth_type: none` is not made user-authenticated by the runtime API key. This key only authenticates the tunnel process to the OpenAI control plane.
3. Gateway mode requires an actual OAuth-protected resource endpoint or sidecar and an authorization server/IdP with a browser-reachable authorization endpoint. A static bearer header is not a substitute for user identity.
4. Before enabling gateway mode, prove that every MCP request (including discovery, streaming and sessions) is validated and that upstream bypass is blocked.
5. Existing add-on settings must remain backwards compatible. Avoid presenting an unimplemented mode in the Home Assistant configuration.

## Next implementation milestone
Build a separately testable OAuth resource-server gateway, with an external IdP and explicit allowlisted principals, only after selecting a supported provider and verifying its metadata endpoints. Integration into the manager can then be an opt-in per-tunnel local upstream URL. No secrets or insecure defaults should be committed.

## Proposed Authentik deployment (design, not deployed)
- Run Authentik and its persistent PostgreSQL database as a separately maintained service, not inside the existing Bash tunnel manager.
- Expose only Authentik's HTTPS authorization/OIDC endpoints via a controlled public ingress (e.g. Cloudflare Tunnel and a dedicated auth subdomain). Do not expose the Home Assistant UI, MCP origins or database.
- Require MFA and restrict the OAuth application to an explicit user/group allowlist.
- Implement an opt-in generic OAuth resource-server gateway before the local MCP origin; validate issuer, audience/resource, signature/JWKS, expiry, scopes and user identity on every call. Handle OAuth protected-resource metadata, 401 challenges, streaming and session continuity.
- Keep the existing upstream authentication settings separate. Current Postgram/Todo tunnels must remain unchanged until independently tested.
- Use Authorization Code + PKCE for interactive login. Confirm Authentik's OAuth client-registration capabilities against ChatGPT's current connector requirements before selecting registration strategy; do not assume dynamic client registration works.
- Threat-model direct origin access, forwarded headers, token replay, open redirects, oversized requests and file path traversal.
- Roll out to File Extractor first with a deny-by-default policy; only then consider other MCPs.
- Example domain auth.lukkezen.name is illustrative; no DNS, tunnel or provider configuration has been performed.

## Pocket ID pilot (2026-10-09)
Verified community HAOS app: https://github.com/einschmidt/hassio-addons/tree/main/pocket-id
- App version at inspection: 1.4.7; amd64 and aarch64; port 1411; persistent /app/data.
- APP_URL must be public HTTPS. Prefer TRUST_PROXY_LIST restricted to the exact ingress proxy IP/CIDR; do not blindly enable TRUST_PROXY.
- Run as an independent Home Assistant app. Do not expose HA UI, MCP backends or data directory.
- Before installation, confirm a safe HTTPS ingress and backup/storage location. Before connector enablement, verify Pocket ID OIDC discovery, client type, authorization-code PKCE, redirect URI support, and OpenAI connector registration compatibility.
- Pocket ID is an identity provider, not an MCP authorization gateway. Gateway still needs audience/issuer/scope/user validation and protected resource metadata.
- Existing tunnels remain unchanged. First pilot only on File Extractor, with negative authorization tests.
