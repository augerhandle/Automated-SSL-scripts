#!/usr/bin/env bash

# Source required dependencies (assuming they exist in your lib directory)
source "lib/assert.sh"
source "lib/logging.sh"

# ==============================================================================
# SUB-FUNCTIONS (Modular & Unit-Testable without network)
# ==============================================================================

# Constructs the full URL from a base URL and an endpoint path.
# Usage: build_full_url "https://api.example.com" "/v1/users"
build_full_url() {
    assert_argc 2 $#
    local base_url="$1"
    local endpoint="$2"
    
    # Strip trailing slash from base and leading slash from endpoint for clean join
    base_url="${base_url%/}"
    endpoint="${endpoint#/}"
    
    echo "${base_url}/${endpoint}"
}

# Constructs a curl-compatible header array from a standardized format
# Usage: build_curl_headers "Content-Type: application/json" "Authorization: Bearer token"
build_curl_headers() {
    local headers=("$@")
    local curl_header_args=()
    
    for header in "${headers[@]}"; do
        curl_header_args+=("-H" "${header}")
    done
    
    # Print the array elements quoted so the caller can eval/read them back
    printf '%q ' "${curl_header_args[@]}"
}

# ==============================================================================
# MAIN HTTP REQUEST FUNCTION
# ==============================================================================

# Sends an HTTP request and evaluates the response.
# Usage: send_http_request <METHOD> <BASE_URL> <ENDPOINT> <PAYLOAD_FILE>
send_http_request() {
    # --------------------------------------------------------------------------
    # 1. PRE-CONDITIONS & ASSERTIONS
    # --------------------------------------------------------------------------
    assert_cmds curl
    assert_min_argc 3 $#
    
    local HTTP_METHOD="$1"
    local BASE_URL="$2"
    local ENDPOINT="$3"
    local PAYLOAD_FILE="${4:-}"
    
    # Verify core variables are set
    assert_nonempty HTTP_METHOD
    assert_nonempty BASE_URL
    
    if [[ -n "$PAYLOAD_FILE" ]]; then
        assert_file_readable PAYLOAD_FILE
    fi

    # --------------------------------------------------------------------------
    # 2. HTTP CONFIGURATION & SETUP
    # --------------------------------------------------------------------------
    log_info "Configuring HTTP request"
    
    local FULL_URL
    FULL_URL=$(build_full_url "$BASE_URL" "$ENDPOINT")
    
    # Define HTTP Headers clearly
    local RAW_HEADERS=(
        "Accept: application/json"
        "Content-Type: application/json"
        "User-Agent: Bash-API-Client/1.0"
    )
    
    # Generate curl header arguments
    local CURL_HEADERS
    eval "CURL_HEADERS=($(build_curl_headers "${RAW_HEADERS[@]}"))"

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
        "$FULL_URL"
    )

    if [[ -n "$PAYLOAD_FILE" ]]; then
        CURL_CMD+=("--data" "@${PAYLOAD_FILE}")
        log_verbose "Attaching request payload from: $PAYLOAD_FILE"
    fi

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