#!/usr/bin/with-contenv bashio
set -Eeuo pipefail

readonly OPTIONS_FILE="/data/options.json"
readonly RESTART_DELAY=5
declare -a SUPERVISOR_PIDS=()

log_tunnel() {
    local level="$1"
    local name="$2"
    shift 2
    case "$level" in
        info) bashio::log.info "[${name}] $*" ;;
        warning) bashio::log.warning "[${name}] $*" ;;
        error) bashio::log.error "[${name}] $*" ;;
        *) bashio::log.info "[${name}] $*" ;;
    esac
}

sanitize_name() {
    printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '_'
}

append_header() {
    local current="$1"
    local header="$2"

    if [[ -z "$header" ]]; then
        printf '%s' "$current"
    elif [[ -z "$current" ]]; then
        printf '%s' "$header"
    else
        printf '%s, %s' "$current" "$header"
    fi
}

supervise_tunnel() {
    local item_json="$1"
    local index="$2"

    local name provider tunnel_id runtime_api_key mcp_server_url
    local mcp_auth_type mcp_api_key mcp_api_key_header custom_headers legacy_mcp_headers
    local discovery_headers log_level safe_name health_port
    local mcp_headers="" generated_auth_header=""
    local tunnel_pid=""

    name="$(jq -r '.name' <<<"$item_json")"
    provider="$(jq -r '.provider' <<<"$item_json")"
    tunnel_id="$(jq -r '.tunnel_id' <<<"$item_json")"
    runtime_api_key="$(jq -r '.runtime_api_key' <<<"$item_json")"
    mcp_server_url="$(jq -r '.mcp_server_url' <<<"$item_json")"
    mcp_auth_type="$(jq -r '.mcp_auth_type // empty' <<<"$item_json")"
    mcp_api_key="$(jq -r '.mcp_api_key // ""' <<<"$item_json")"
    mcp_api_key_header="$(jq -r '.mcp_api_key_header // "X-API-Key"' <<<"$item_json")"
    custom_headers="$(jq -r '.custom_headers // ""' <<<"$item_json")"
    legacy_mcp_headers="$(jq -r '.mcp_headers // ""' <<<"$item_json")"
    discovery_headers="$(jq -r '.discovery_headers // ""' <<<"$item_json")"
    log_level="$(jq -r '.log_level' <<<"$item_json")"
    safe_name="$(sanitize_name "$name")"
    health_port="$((8100 + index))"

    if [[ "$provider" != "openai" ]]; then
        log_tunnel error "$name" "Unsupported provider: $provider"
        return 1
    fi

    if [[ ! "$tunnel_id" =~ ^tunnel_[a-f0-9]{32}$ ]]; then
        log_tunnel error "$name" "Invalid OpenAI tunnel ID. Expected tunnel_ followed by 32 lowercase hexadecimal characters."
        return 1
    fi

    if [[ -z "$runtime_api_key" ]]; then
        log_tunnel error "$name" "runtime_api_key is required."
        return 1
    fi

    if [[ ! "$mcp_server_url" =~ ^https?:// ]]; then
        log_tunnel error "$name" "mcp_server_url must use http:// or https://."
        return 1
    fi

    if [[ -z "$mcp_auth_type" ]]; then
        if [[ -n "$mcp_api_key" ]]; then
            mcp_auth_type="bearer"
        elif [[ -n "$legacy_mcp_headers" ]]; then
            mcp_auth_type="legacy"
        else
            mcp_auth_type="none"
        fi
    fi

    case "$mcp_auth_type" in
        none|legacy)
            ;;
        bearer|api_key)
            if [[ -z "$mcp_api_key" ]]; then
                log_tunnel error "$name" "mcp_api_key is required when mcp_auth_type is '$mcp_auth_type'."
                return 1
            fi
            ;;
        *)
            log_tunnel error "$name" "Unsupported mcp_auth_type: $mcp_auth_type"
            return 1
            ;;
    esac

    if [[ "$mcp_auth_type" == "api_key" && -z "$mcp_api_key_header" ]]; then
        log_tunnel error "$name" "mcp_api_key_header is required for api_key authentication."
        return 1
    fi

    local secret_dir="/data/secrets/${safe_name}"
    local runtime_key_file="${secret_dir}/runtime_api_key"
    mkdir -p "$secret_dir"
    chmod 0700 "$secret_dir"
    umask 077

    printf '%s' "$runtime_api_key" > "$runtime_key_file"
    chmod 0600 "$runtime_key_file"
    unset runtime_api_key

    if [[ "$mcp_auth_type" == "bearer" ]]; then
        generated_auth_header="Authorization: Bearer ${mcp_api_key}"
    elif [[ "$mcp_auth_type" == "api_key" ]]; then
        generated_auth_header="${mcp_api_key_header}: ${mcp_api_key}"
    fi

    if [[ "$mcp_auth_type" == "legacy" ]]; then
        mcp_headers="$(append_header "$legacy_mcp_headers" "$custom_headers")"
    else
        mcp_headers="$(append_header "$generated_auth_header" "$custom_headers")"
    fi

    cleanup_tunnel() {
        if [[ -n "$tunnel_pid" ]] && kill -0 "$tunnel_pid" 2>/dev/null; then
            kill -TERM "$tunnel_pid" 2>/dev/null || true
            wait "$tunnel_pid" 2>/dev/null || true
        fi
        exit 0
    }
    trap cleanup_tunnel TERM INT

    while true; do
        log_tunnel info "$name" "Starting OpenAI tunnel -> $mcp_server_url"

        (
            export CONTROL_PLANE_TUNNEL_ID="$tunnel_id"
            export MCP_SERVER_URL="$mcp_server_url"
            export MCP_STARTUP_WAIT_TIMEOUT="60s"
            export MCP_MAX_CONCURRENT_REQUESTS="20"
            export HEALTH_LISTEN_ADDR="127.0.0.1:${health_port}"
            export LOG_LEVEL="$log_level"
            export LOG_FORMAT="struct-text"
            export LOG_HTTP_RAW_UNSAFE="false"
            export ALLOW_REMOTE_UI="false"

            if [[ -n "$mcp_headers" ]]; then
                export MCP_EXTRA_HEADERS="$mcp_headers"
            else
                unset MCP_EXTRA_HEADERS || true
            fi

            if [[ -n "$discovery_headers" ]]; then
                export MCP_DISCOVERY_EXTRA_HEADERS="$discovery_headers"
            elif [[ -n "$mcp_headers" ]]; then
                export MCP_DISCOVERY_EXTRA_HEADERS="$mcp_headers"
            else
                unset MCP_DISCOVERY_EXTRA_HEADERS || true
            fi

            exec /usr/local/bin/tunnel-client run \
                --control-plane.api-key="file:${runtime_key_file}"
        ) &
        tunnel_pid="$!"

        set +e
        wait "$tunnel_pid"
        local status="$?"
        set -e
        tunnel_pid=""

        log_tunnel warning "$name" "Tunnel exited with status $status; restarting in ${RESTART_DELAY}s."
        sleep "$RESTART_DELAY"
    done
}

shutdown_all() {
    trap - TERM INT EXIT
    bashio::log.info "Stopping MCP Tunnel Manager..."
    for pid in "${SUPERVISOR_PIDS[@]:-}"; do
        kill -TERM "$pid" 2>/dev/null || true
    done
    for pid in "${SUPERVISOR_PIDS[@]:-}"; do
        wait "$pid" 2>/dev/null || true
    done
    exit 0
}

trap shutdown_all TERM INT

if [[ ! -f "$OPTIONS_FILE" ]]; then
    bashio::exit.nok "Home Assistant options file not found."
fi

tunnel_count="$(jq '.tunnels | length' "$OPTIONS_FILE")"
if [[ "$tunnel_count" -eq 0 ]]; then
    bashio::log.warning "No tunnels configured. Add at least one tunnel in the add-on configuration."
    while true; do sleep 3600; done
fi

enabled_count=0
index=0
while IFS= read -r encoded; do
    item_json="$(printf '%s' "$encoded" | base64 -d)"
    enabled="$(jq -r '.enabled' <<<"$item_json")"
    name="$(jq -r '.name' <<<"$item_json")"

    if [[ "$enabled" != "true" ]]; then
        log_tunnel info "$name" "Disabled; skipping."
        index="$((index + 1))"
        continue
    fi

    supervise_tunnel "$item_json" "$index" &
    SUPERVISOR_PIDS+=("$!")
    enabled_count="$((enabled_count + 1))"
    index="$((index + 1))"
done < <(jq -r '.tunnels[] | @base64' "$OPTIONS_FILE")

if [[ "$enabled_count" -eq 0 ]]; then
    bashio::log.warning "All configured tunnels are disabled."
    while true; do sleep 3600; done
fi

bashio::log.info "Started $enabled_count tunnel supervisor(s)."

set +e
wait
status="$?"
set -e
bashio::log.error "Tunnel manager wait loop exited unexpectedly with status $status."
shutdown_all
