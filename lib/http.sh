#!/usr/bin/env bash

# ========================================================================
# HTTP request/response functions
# ========================================================================

# prevent sourcing multiple times
[ -n "${_DAH_HTTP_SH:-}" ] && return 0

# ========================================================================
# dependencies
# ========================================================================
# Resolve directory relative to THIS library file
_DAH_HTTP_SH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DAH_HTTP_SH_LIB_DIR="${_DAH_HTTP_SH_SCRIPT_DIR}"

# Source dependencies
source "${_DAH_HTTP_SH_LIB_DIR}/logging.sh"
source "${_DAH_HTTP_SH_LIB_DIR}/assert.sh"

# ==============================================================================
# SUB-FUNCTIONS (Modular & Unit-Testable without network)
# ==============================================================================

# ------------------------------------------------------------------------------
# Constructs the URL from a base URL and an endpoint path.
# Prepends "https://" if no http:// or https:// scheme is present.
#
# Arguments:
#   $1 - Base host or URL (e.g., "api.example.com" or "https://api.example.com")
#   $2 - API endpoint path (e.g., "/v1/users")
# Outputs:
#   Writes the normalized full URL to stdout.
# Example:
#   build_url "api.example.com" "/v1/users"
#   # => https://api.example.com/v1/users
# ------------------------------------------------------------------------------
build_url() {
    assert_argc 2 $#
    local base_url="$1"
    local endpoint="$2"

    log_verbose_vars base_url endpoint

    # ---------------
    # PRE-CONDITIONS
    # ---------------
    # base_url must be 
    # - non-empty, 
    # - whitespace-free, and 
    # - contain a valid host segment with an optional http:// or https:// scheme 
    #   (so it rejects "", "http://", "https://", "/")
    assert_true "base_url must be a valid host with optional http(s):// scheme and no whitespace" \
        bash -c '
            url="$1"
            if [[ "$url" =~ ^https?:// ]]; then
                [[ "$url" =~ ^https?://[^/[:space:]]+(/[^[:space:]]*)?$ ]]
            else
                [[ "$url" =~ ^[^/:[:space:]]+(:[0-9]+)?(/[^[:space:]]*)?$ ]]
            fi
        ' _ "$base_url"

    # - endpoint may be empty, but must not contain whitespace
    assert_true "endpoint must not contain whitespace" test -z "${endpoint//[^[:space:]]/}"

    # ---------------
    # IMPLEMENTATION
    # ---------------
    # Prepend https:// if neither http:// nor https:// is present
    if [[ ! "$base_url" =~ ^https?:// ]]; then
        base_url="https://${base_url}"
        log_verbose "Prepended https:// scheme to base_url"
    fi

    # Strip trailing slash from base and leading slash from endpoint for clean join
    base_url="${base_url%/}"
    endpoint="${endpoint#/}"

    local full_url="${base_url}/${endpoint}"
    log_verbose_vars full_url

    # ---------------
    # POST-CONDITIONS
    # ---------------
    assert_nonempty full_url
    assert_true "full_url must be a valid http(s) URL with host and no whitespace" \
        bash -c '[[ "$1" =~ ^https?://[^/[:space:]]+/[^[:space:]]*$ ]]' _ "$full_url"

    echo "${full_url}"
}

# ------------------------------------------------------------------------------
# Formats "Name: Value" header arguments into shell-quoted curl -H flags.
#
# Arguments:
#   $@ - One or more HTTP header strings in "Name: Value" format
# Outputs:
#   Writes shell-quoted "-H <header>" arguments to stdout (safe for eval).
# Example:
#   build_curl_headers "Accept: application/json" "Authorization: cpanel user:token"
#   # => -H Accept:\ application/json -H Authorization:\ cpanel\ user:token
# ------------------------------------------------------------------------------
build_curl_headers() {
    log_verbose "Building curl headers for $# header(s)"

    # ---------------
    # PRE-CONDITIONS
    # ---------------
    local header
    for header in "$@"; do
        assert_nonempty header
        assert_true "header must not contain CR or LF characters" \
            bash -c '[[ "$1" != *$'\''\n'\''* && "$1" != *$'\''\r'\''* ]]' _ "$header"
        assert_true "header must match 'Name: Value' format" \
            bash -c '[[ "$1" =~ ^[^:[:space:]]+: ]]' _ "$header"
    done

    # ---------------
    # IMPLEMENTATION
    # ---------------
    if [[ $# -eq 0 ]]; then
        log_verbose "No headers provided; returning empty argument list"
        return 0
    fi

    local curl_header_args=()
    for header in "$@"; do
        log_verbose_vars header
        curl_header_args+=("-H" "${header}")
    done

    local serialized_args
    serialized_args=$(printf '%q ' "${curl_header_args[@]}")
    log_verbose_vars serialized_args

    # Print the array elements quoted so the caller can eval/read them back
    printf '%s' "${serialized_args}"
}

# ------------------------------------------------------------------------------
# Formats "key=value" parameter arguments into shell-quoted curl --data-urlencode flags.
#
# Arguments:
#   $@ - One or more parameter strings in "key=value" format
# Outputs:
#   Writes shell-quoted "--data-urlencode <param>" arguments to stdout (safe for eval).
# Example:
#   build_curl_params "domain=example.com" "email=admin@example.com"
#   # => --data-urlencode domain=example.com --data-urlencode email=admin@example.com
# ------------------------------------------------------------------------------
build_curl_params() {
    log_verbose "Building curl parameters for $# parameter(s)"

    # ---------------
    # PRE-CONDITIONS
    # ---------------
    # Each parameter must be non-empty and match "key=value" where key has no '=' or whitespace.
    # (Value may be empty, contain '=', spaces, newlines, or special characters since curl URL-encodes it.)
    local param
    for param in "$@"; do
        assert_nonempty param
        assert_true "param must match 'key=value' format with a non-empty, whitespace-free key" \
            bash -c '[[ "$1" =~ ^[^=[:space:]]+= ]]' _ "$param"
    done

    # ---------------
    # IMPLEMENTATION
    # ---------------
    if [[ $# -eq 0 ]]; then
        log_verbose "No parameters provided; returning empty argument list"
        return 0
    fi

    local curl_param_args=()
    for param in "$@"; do
        log_verbose_vars param
        curl_param_args+=("--data-urlencode" "${param}")
    done

    local serialized_args
    serialized_args=$(printf '%q ' "${curl_param_args[@]}")
    log_verbose_vars serialized_args

    # ---------------
    # POST-CONDITIONS
    # ---------------
    assert_nonempty serialized_args

    # Print the array elements quoted so the caller can eval/read them back
    printf '%s' "${serialized_args}"
}

# ==============================================================================
# MAIN HTTP REQUEST FUNCTION
# ==============================================================================

# Sends an HTTP request with URL-encoded parameters and optional custom headers.
# Usage: send_http_request <METHOD> <BASE_URL> <ENDPOINT> [HEADERS_STR] [PARAM_1 PARAM_2 ...]
#
# Arguments:
#   METHOD      - HTTP verb (e.g., GET, POST)
#   BASE_URL    - Host or base URL (e.g., "cpanel.example.com:2083")
#   ENDPOINT    - API endpoint path (e.g., "/execute/Email/list_pops")
#   HEADERS_STR - Optional newline-delimited string of custom headers
#                 (e.g., $'Authorization: cpanel user:token\nX-Custom: val')
#   PARAM_N     - Optional key=value parameter pairs to URL-encode
send_http_request() {
    # --------------------------------------------------------------------------
    # 1. PRE-CONDITIONS & ASSERTIONS
    # --------------------------------------------------------------------------
    assert_cmds curl
    assert_min_argc 3 $#
    
    local HTTP_METHOD="$1"
    local BASE_URL="$2"
    local ENDPOINT="$3"
    local CUSTOM_HEADERS_STR="${4:-}"
    shift 3
    if [[ $# -gt 0 ]]; then
        shift 1
    fi
    local RAW_PARAMS=("$@")
    
    # Verify core variables are set
    assert_nonempty HTTP_METHOD
    assert_nonempty BASE_URL

    # --------------------------------------------------------------------------
    # 2. HTTP CONFIGURATION & SETUP
    # --------------------------------------------------------------------------
    log_info "Configuring HTTP request"
    
    local FULL_URL
    FULL_URL=$(build_url "$BASE_URL" "$ENDPOINT")
    
    # Define default HTTP Headers (no Content-Type; curl sets it automatically on POST)
    local RAW_HEADERS=(
        "Accept: application/json"
        "User-Agent: Bash-API-Client/1.0"
    )

    # Append any newline-delimited custom headers (such as Authorization)
    if [[ -n "$CUSTOM_HEADERS_STR" ]]; then
        while IFS= read -r custom_header; do
            if [[ -n "$custom_header" ]]; then
                RAW_HEADERS+=("$custom_header")
            fi
        done <<< "$CUSTOM_HEADERS_STR"
    fi
    
    # Generate curl header arguments
    local CURL_HEADERS
    eval "CURL_HEADERS=($(build_curl_headers "${RAW_HEADERS[@]}"))"

    # Generate curl URL-encoded parameter arguments
    local CURL_PARAMS=()
    if [[ ${#RAW_PARAMS[@]} -gt 0 ]]; then
        eval "CURL_PARAMS=($(build_curl_params "${RAW_PARAMS[@]}"))"
    fi

    # Setup temporary file to capture the HTTP response body and status code
    local RESPONSE_BODY_FILE
    RESPONSE_BODY_FILE=$(mktemp)
    
    log_verbose "HTTP_METHOD=$HTTP_METHOD"
    log_verbose "FULL_URL=$FULL_URL"
    
    # --------------------------------------------------------------------------
    # 3. HTTP EXECUTION (THE REQUEST)
    # --------------------------------------------------------------------------
    log_info "Executing HTTP $HTTP_METHOD request to $FULL_URL"
    
    local CURL_CMD=(
        curl 
        --silent 
        --show-error 
        --request "$HTTP_METHOD" 
        --write-out "%{http_code}" 
        --output "$RESPONSE_BODY_FILE"
        "${CURL_HEADERS[@]}"
    )

    if [[ ${#CURL_PARAMS[@]} -gt 0 ]]; then
        # For GET requests, instruct curl to append --data-urlencode items to the query string
        case "$HTTP_METHOD" in
            GET|get)
                CURL_CMD+=("--get")
                ;;
        esac
        CURL_CMD+=("${CURL_PARAMS[@]}")
        log_verbose "Attaching ${#RAW_PARAMS[@]} URL-encoded parameter(s)"
    fi

    CURL_CMD+=("$FULL_URL")

    # Execute curl and capture the HTTP status code written to stdout
    local HTTP_STATUS_CODE
    HTTP_STATUS_CODE=$("${CURL_CMD[@]}")
    local CURL_EXIT_CODE=$?

    # --------------------------------------------------------------------------
    # 4. RESPONSE HANDLING & EVALUATION
    # --------------------------------------------------------------------------
    log_info "Evaluating HTTP response"
    
    # Read the response body from the temp file
    local HTTP_RESPONSE_BODY
    HTTP_RESPONSE_BODY=$(<"$RESPONSE_BODY_FILE")
    rm -f "$RESPONSE_BODY_FILE"

    log_verbose "CURL_EXIT_CODE=$CURL_EXIT_CODE"
    log_verbose "HTTP_STATUS_CODE=$HTTP_STATUS_CODE"
    log_verbose "HTTP_RESPONSE_BODY=$HTTP_RESPONSE_BODY"

    # Check for infrastructure/curl failure
    if [[ $CURL_EXIT_CODE -ne 0 ]]; then
        log_err "Curl execution failed with exit code $CURL_EXIT_CODE"
        return 1
    fi

    # Check for HTTP API error conditions (4xx or 5xx)
    if [[ "$HTTP_STATUS_CODE" -ge 400 ]]; then
        log_err "API returned error status: $HTTP_STATUS_CODE"
        log_err "Error Response: $HTTP_RESPONSE_BODY"
        return 1
    fi

    # Success
    log_info "Request successful (Status: $HTTP_STATUS_CODE)"
    
    # Return the body to the caller via stdout
    echo "$HTTP_RESPONSE_BODY"
    return 0
}

# Set guard only after everything in the file loaded cleanly
_DAH_HTTP_SH=1