#!/usr/bin/env bash

# ========================================================================
# cPanel UAPI Protocol Adapter
# Dependencies: assert.sh, logging.sh, http.sh
# ========================================================================

# ------------------------------------------------------------------------
# Internal Helpers
# ------------------------------------------------------------------------

# Validates required cPanel connection environment variables
_cpanel_validate_env() {
    assert_nonempty CPANEL_HOST
    assert_nonempty CPANEL_USER
    assert_nonempty CPANEL_TOKEN

    # Ensure no whitespace or colon injection in user/token
    assert_true "CPANEL_USER must not contain whitespace or colons" \
        test -z "$(printf '%s' "$CPANEL_USER" | tr -d '[:graph:]')"
    assert_true "CPANEL_USER must not contain ':'" \
        [[ "$CPANEL_USER" != *:* ]]
    assert_true "CPANEL_TOKEN must not contain whitespace" \
        test -z "$(printf '%s' "$CPANEL_TOKEN" | tr -d '[:graph:]')"
}

# Builds the cPanel base URL (defaults to https://<CPANEL_HOST>:2083)
# Allows explicit http:// or https:// and custom ports in CPANEL_HOST or CPANEL_PORT
_cpanel_build_base_url() {
    local host="$CPANEL_HOST"
    local port="${CPANEL_PORT:-2083}"

    assert_true "CPANEL_PORT must be numeric" [[ "$port" =~ ^[0-9]+$ ]]

    # If host already specifies a scheme or explicit port, preserve it
    if [[ "$host" =~ ^https?:// ]] || [[ "$host" =~ :[0-9]+(/|$) ]]; then
        printf '%s' "$host"
    else
        printf 'https://%s:%s' "$host" "$port"
    fi
}

# Inspects a cPanel UAPI JSON response for application-level errors ("status": 0)
# Returns 0 if status is 1 (or valid non-error response), 1 if status is 0
_cpanel_check_response() {
    local response="$1"

    assert_min_argc 1 $#

    if [[ -z "$response" ]]; then
        log_err "cPanel UAPI returned an empty response body."
        return 1
    fi

    # Detect cPanel application-level failure ("status":0 or "status": 0)
    if [[ "$response" =~ \"status\"[[:space:]]*:[[:space:]]*0([^0-9]|$) ]]; then
        log_err "cPanel UAPI reported application error (status: 0)."
        log_err "Response payload: $response"
        return 1
    fi

    # Verify positive status indicator ("status":1 or "status": 1)
    if [[ ! "$response" =~ \"status\"[[:space:]]*:[[:space:]]*1([^0-9]|$) ]]; then
        log_err "cPanel UAPI returned unexpected response format (missing 'status': 1)."
        log_err "Response payload: $response"
        return 1
    fi

    return 0
}

# ------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------

# Executes a cPanel UAPI request and validates the JSON response envelope.
#
# Environment Variables:
#   CPANEL_HOST   (Required) Hostname or base URL (e.g., cpanel.example.com)
#   CPANEL_USER   (Required) cPanel account username
#   CPANEL_TOKEN  (Required) cPanel API token
#   CPANEL_PORT   (Optional) Port number (default: 2083)
#
# Arguments:
#   $1 - HTTP_METHOD (e.g., GET, POST)
#   $2 - MODULE      (e.g., Email, Mysql, DomainInfo)
#   $3 - FUNCTION    (e.g., list_pops, add_pop)
#   $@ - Optional key=value parameters passed to send_http_request
#
# Outputs:
#   Prints the raw JSON response on stdout when status == 1
#   Returns 0 on success, 1 on validation, transport, HTTP, or UAPI error
cpanel_uapi_request() {
    assert_min_argc 3 $#

    local http_method="$1"
    local module="$2"
    local func="$3"
    shift 3

    assert_nonempty http_method
    assert_nonempty module
    assert_nonempty func

    # Module and function names should be clean path segments (no slashes or spaces)
    assert_true "MODULE must be a valid UAPI module identifier" \
        [[ "$module" =~ ^[A-Za-z0-9_]+$ ]]
    assert_true "FUNCTION must be a valid UAPI function identifier" \
        [[ "$func" =~ ^[A-Za-z0-9_]+$ ]]

    _cpanel_validate_env

    local base_url
    base_url="$(_cpanel_build_base_url)"

    local endpoint="/execute/${module}/${func}"
    local auth_header="Authorization: cpanel ${CPANEL_USER}:${CPANEL_TOKEN}"

    log_verbose "cPanel UAPI Request: ${http_method} ${base_url}${endpoint}"

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