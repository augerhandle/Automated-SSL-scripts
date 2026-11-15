#!/usr/bin/env bash

# ========================================================================
# cPanel UAPI Protocol Adapter
# Dependencies: assert.sh, logging.sh, http.sh
# ========================================================================

# ------------------------------------------------------------------------
# Internal Helpers
# ------------------------------------------------------------------------

# Validates required and optional cPanel connection environment variables
_cpanel_validate_env() {
    log_verbose "Validating cPanel environment variables"

    assert_nonempty CPANEL_HOST
    assert_nonempty CPANEL_USER
    assert_nonempty CPANEL_TOKEN

    local port="${CPANEL_PORT:-2083}"

    log_verbose_vars CPANEL_HOST CPANEL_USER port
    log_verbose_secret_vars CPANEL_TOKEN

    assert_not_regex "CPANEL_HOST must not contain whitespace" "$CPANEL_HOST" '[[:space:]]'
    assert_regex "CPANEL_HOST must be a valid hostname or http(s) URL" \
        "$CPANEL_HOST" '^(https?://)?[A-Za-z0-9.-]+(:[0-9]+)?(/.*)?$'

    assert_not_regex "CPANEL_USER must not contain whitespace or ':'" "$CPANEL_USER" '[[:space:]:]'
    assert_regex "CPANEL_PORT must be numeric" "$port" '^[0-9]+$'

    # Keep CPANEL_TOKEN check manual so a malformed token is never printed by assert_not_regex
    if [[ "$CPANEL_TOKEN" =~ [[:space:]] ]]; then
        log_fatal "CPANEL_TOKEN must not contain whitespace"
    fi

    log_verbose "cPanel environment validation passed"
}

# Builds the cPanel base URL (defaults to https://<CPANEL_HOST>:2083)
_cpanel_build_base_url() {
    local host="$CPANEL_HOST"
    local port="${CPANEL_PORT:-2083}"
    local base_url

    if [[ "$host" =~ ^https?:// ]] || [[ "$host" =~ :[0-9]+(/|$) ]]; then
        base_url="$host"
        log_verbose "Using explicit scheme/port from CPANEL_HOST: $base_url"
    else
        base_url="https://${host}:${port}"
        log_verbose "Built default cPanel base URL: $base_url"
    fi

    printf '%s' "$base_url"
}

# Inspects a cPanel UAPI JSON response for application-level errors ("status": 0)
_cpanel_check_response() {
    local response="$1"

    assert_min_argc 1 $#
    log_verbose "Inspecting cPanel UAPI response payload (${#response} bytes)"

    if [[ -z "$response" ]]; then
        log_err "cPanel UAPI returned an empty response body."
        return 1
    fi

    if [[ "$response" =~ \"status\"[[:space:]]*:[[:space:]]*0([^0-9]|$) ]]; then
        log_err "cPanel UAPI reported application error (status: 0)."
        log_err "Response payload: $response"
        return 1
    fi

    if [[ ! "$response" =~ \"status\"[[:space:]]*:[[:space:]]*1([^0-9]|$) ]]; then
        log_err "cPanel UAPI returned unexpected response format (missing 'status': 1)."
        log_err "Response payload: $response"
        return 1
    fi

    log_verbose "cPanel UAPI response verified (status: 1)"
    return 0
}

# ------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------

# Executes a cPanel UAPI request and validates the JSON response envelope.
#
# Required Environment Variables (never persisted or logged in plaintext):
#   CPANEL_HOST   Hostname or base URL (e.g., cpanel.example.com)
#   CPANEL_USER   cPanel account username
#   CPANEL_TOKEN  cPanel API token
# Optional Environment Variables:
#   CPANEL_PORT   Port number (default: 2083)
#
# Arguments:
#   $1 - HTTP_METHOD (e.g., GET, POST)
#   $2 - MODULE      (e.g., Email, Mysql, DomainInfo)
#   $3 - FUNCTION    (e.g., list_pops, add_pop)
#   $@ - Optional key=value parameters passed to send_http_request
cpanel_uapi_request() {
    assert_min_argc 3 $#

    local http_method="$1"
    local module="$2"
    local func="$3"
    shift 3

    assert_nonempty http_method
    assert_nonempty module
    assert_nonempty func

    assert_regex "HTTP_METHOD must be an uppercase standard HTTP verb (GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS)" \
        "$http_method" '^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)$'
    assert_regex "MODULE must be a valid UAPI module identifier" "$module" '^[A-Za-z0-9_]+$'
    assert_regex "FUNCTION must be a valid UAPI function identifier" "$func" '^[A-Za-z0-9_]+$'

    _cpanel_validate_env

    local base_url
    base_url="$(_cpanel_build_base_url)"

    local endpoint="/execute/${module}/${func}"
    local auth_header="Authorization: cpanel ${CPANEL_USER}:${CPANEL_TOKEN}"

    log_verbose "cPanel UAPI Request: ${http_method} ${base_url}${endpoint}"
    log_verbose_vars CPANEL_USER
    log_verbose_secret_vars CPANEL_TOKEN

    local response
    if ! response="$(send_http_request "$http_method" "$base_url" "$endpoint" "$auth_header" "$@")"; then
        return 1
    fi

    if ! _cpanel_check_response "$response"; then
        return 1
    fi

    printf '%s\n' "$response"
    return 0
}