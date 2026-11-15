#!/usr/bin/env bash

# ========================================================================
# Test script for send_cpanel_uapi_request in cpanel.sh
# ========================================================================

# ------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
TEST_DIR="${SCRIPT_DIR}"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/assert.sh"
source "${LIB_DIR}/http.sh"
source "${LIB_DIR}/cpanel.sh"
source "${TEST_DIR}/test_helpers.sh"

# ------------------------------------------------------------------------
# Test Fixtures & Helpers
# ------------------------------------------------------------------------

VALID_UAPI_SUCCESS='{"status": 1, "errors": null, "messages": null, "data": ["ok"]}'
VALID_UAPI_APP_ERROR='{"status": 0, "errors": ["Access denied"], "messages": null, "data": null}'

set_valid_cpanel_env() {
    export CPANEL_HOST="cpanel.example.com"
    export CPANEL_USER="testuser"
    export CPANEL_TOKEN="super_secret_token_98765"
    unset CPANEL_PORT
}

# Sentinel mock: fails immediately if send_http_request is reached during validation tests
mock_http_should_not_run() {
    send_http_request() {
        echo "MOCK_CALLED_UNEXPECTEDLY" >&2
        return 99
    }
}

# Portable Bash 3.2+ replacement for `mapfile -t CAPTURED_ARGS < "$file"`
load_captured_args() {
    local file="$1"
    CAPTURED_ARGS=()
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        CAPTURED_ARGS+=("$line")
    done < "$file"
}

# ------------------------------------------------------------------------
# Test Cases
# ------------------------------------------------------------------------

echo "Running send_cpanel_uapi_request tests..."
echo "------------------------------------------------"

# ========================================================================
# 1. Pre-Network Argument & Identifier Validation
# ========================================================================

test_header "send_cpanel_uapi_request (Failure expected - fewer than 3 arguments)"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    mock_http_should_not_run
    send_cpanel_uapi_request "GET" "Email" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" == *"MOCK_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "send_http_request was called despite missing arguments"
else
    test_pass "Missing argument caught before HTTP call."
fi

test_header "send_cpanel_uapi_request (Failure expected - empty HTTP_METHOD)"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    mock_http_should_not_run
    send_cpanel_uapi_request "" "Email" "list_pops" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 || "$ERR_OUTPUT" == *"MOCK_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "Empty HTTP_METHOD was not caught before HTTP call"
else
    test_pass "Empty HTTP_METHOD caught successfully."
fi

test_header "send_cpanel_uapi_request (Failure expected - empty MODULE)"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    mock_http_should_not_run
    send_cpanel_uapi_request "GET" "" "list_pops" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 || "$ERR_OUTPUT" == *"MOCK_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "Empty MODULE was not caught before HTTP call"
else
    test_pass "Empty MODULE caught successfully."
fi

test_header "send_cpanel_uapi_request (Failure expected - empty FUNCTION)"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    mock_http_should_not_run
    send_cpanel_uapi_request "GET" "Email" "" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 || "$ERR_OUTPUT" == *"MOCK_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "Empty FUNCTION was not caught before HTTP call"
else
    test_pass "Empty FUNCTION caught successfully."
fi

test_header "send_cpanel_uapi_request (Failure expected - lowercase HTTP_METHOD 'get')"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    mock_http_should_not_run
    send_cpanel_uapi_request "get" "Email" "list_pops" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 || "$ERR_OUTPUT" == *"MOCK_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "Lowercase HTTP_METHOD was not caught before HTTP call"
else
    test_pass "Lowercase HTTP_METHOD rejected successfully."
fi

test_header "send_cpanel_uapi_request (Failure expected - unsupported HTTP_METHOD 'TRACE')"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    mock_http_should_not_run
    send_cpanel_uapi_request "TRACE" "Email" "list_pops" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 || "$ERR_OUTPUT" == *"MOCK_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "Unsupported HTTP_METHOD was not caught before HTTP call"
else
    test_pass "Unsupported HTTP_METHOD rejected successfully."
fi

test_header "send_cpanel_uapi_request (Failure expected - path traversal in MODULE '../etc')"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    mock_http_should_not_run
    send_cpanel_uapi_request "GET" "../etc" "list_pops" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 || "$ERR_OUTPUT" == *"MOCK_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "Invalid MODULE path traversal was not caught before HTTP call"
else
    test_pass "Path traversal in MODULE rejected successfully."
fi

test_header "send_cpanel_uapi_request (Failure expected - invalid characters in FUNCTION 'list-pops?x=1')"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    mock_http_should_not_run
    send_cpanel_uapi_request "GET" "Email" "list-pops?x=1" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 || "$ERR_OUTPUT" == *"MOCK_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "Invalid FUNCTION characters were not caught before HTTP call"
else
    test_pass "Invalid FUNCTION characters rejected successfully."
fi

# ========================================================================
# 2. Environment Validation Propagation
# ========================================================================

test_header "send_cpanel_uapi_request (Failure expected - missing CPANEL_HOST)"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    unset CPANEL_HOST
    mock_http_should_not_run
    send_cpanel_uapi_request "GET" "Email" "list_pops" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 || "$ERR_OUTPUT" == *"MOCK_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "Missing CPANEL_HOST was not caught before HTTP call"
else
    test_pass "Missing CPANEL_HOST caught successfully."
fi

test_header "send_cpanel_uapi_request (Failure expected - non-numeric CPANEL_PORT)"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    export CPANEL_PORT="abc"
    mock_http_should_not_run
    send_cpanel_uapi_request "GET" "Email" "list_pops" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 || "$ERR_OUTPUT" == *"MOCK_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "Non-numeric CPANEL_PORT was not caught before HTTP call"
else
    test_pass "Non-numeric CPANEL_PORT caught successfully."
fi

# ========================================================================
# 3. Wire Contract & Argument Forwarding (Mocked send_http_request)
# ========================================================================

test_header "send_cpanel_uapi_request (Success - default port 2083, auth header, endpoint, and stdout payload)"
CAPTURE_FILE="$(mktemp)"
STDOUT_OUTPUT="$(
    set_valid_cpanel_env
    send_http_request() {
        printf '%s\n' "$@" > "$CAPTURE_FILE"
        printf '%s' "$VALID_UAPI_SUCCESS"
        return 0
    }
    send_cpanel_uapi_request "GET" "Email" "list_pops"
)"
STATUS=$?
load_captured_args "$CAPTURE_FILE"
rm -f "$CAPTURE_FILE"

if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0, got $STATUS"
elif [[ "${#CAPTURED_ARGS[@]}" -ne 4 ]]; then
    test_fail "Expected 4 arguments passed to send_http_request, got ${#CAPTURED_ARGS[@]}"
elif [[ "${CAPTURED_ARGS[0]}" != "GET" ]]; then
    test_fail "Expected method 'GET', got '${CAPTURED_ARGS[0]}'"
elif [[ "${CAPTURED_ARGS[1]}" != "https://cpanel.example.com:2083" ]]; then
    test_fail "Expected base_url 'https://cpanel.example.com:2083', got '${CAPTURED_ARGS[1]}'"
elif [[ "${CAPTURED_ARGS[2]}" != "/execute/Email/list_pops" ]]; then
    test_fail "Expected endpoint '/execute/Email/list_pops', got '${CAPTURED_ARGS[2]}'"
elif [[ "${CAPTURED_ARGS[3]}" != "Authorization: cpanel testuser:super_secret_token_98765" ]]; then
    test_fail "Unexpected Authorization header: '${CAPTURED_ARGS[3]}'"
elif [[ "$STDOUT_OUTPUT" != "$VALID_UAPI_SUCCESS" ]]; then
    test_fail "Unexpected stdout payload: '$STDOUT_OUTPUT'"
else
    test_pass "Forwarded method, default URL, endpoint, auth header, and returned valid JSON."
fi

test_header "send_cpanel_uapi_request (Success - custom CPANEL_PORT and forwarded key=value parameters)"
CAPTURE_FILE="$(mktemp)"
STDOUT_OUTPUT="$(
    set_valid_cpanel_env
    export CPANEL_PORT="2087"
    send_http_request() {
        printf '%s\n' "$@" > "$CAPTURE_FILE"
        printf '%s' "$VALID_UAPI_SUCCESS"
        return 0
    }
    send_cpanel_uapi_request "POST" "Email" "add_pop" "email=alice" "domain=example.com" "quota=500"
)"
STATUS=$?
load_captured_args "$CAPTURE_FILE"
rm -f "$CAPTURE_FILE"

if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0, got $STATUS"
elif [[ "${#CAPTURED_ARGS[@]}" -ne 7 ]]; then
    test_fail "Expected 7 arguments passed to send_http_request, got ${#CAPTURED_ARGS[@]}"
elif [[ "${CAPTURED_ARGS[0]}" != "POST" ]]; then
    test_fail "Expected method 'POST', got '${CAPTURED_ARGS[0]}'"
elif [[ "${CAPTURED_ARGS[1]}" != "https://cpanel.example.com:2087" ]]; then
    test_fail "Expected custom port URL 'https://cpanel.example.com:2087', got '${CAPTURED_ARGS[1]}'"
elif [[ "${CAPTURED_ARGS[2]}" != "/execute/Email/add_pop" ]]; then
    test_fail "Expected endpoint '/execute/Email/add_pop', got '${CAPTURED_ARGS[2]}'"
elif [[ "${CAPTURED_ARGS[4]}" != "email=alice" || "${CAPTURED_ARGS[5]}" != "domain=example.com" || "${CAPTURED_ARGS[6]}" != "quota=500" ]]; then
    test_fail "Extra key=value parameters were not forwarded intact: ${CAPTURED_ARGS[*]:4}"
else
    test_pass "Custom port and extra key=value parameters forwarded accurately."
fi

test_header "send_cpanel_uapi_request (Success - explicit http:// scheme in CPANEL_HOST)"
CAPTURE_FILE="$(mktemp)"
(
    set_valid_cpanel_env
    export CPANEL_HOST="http://127.0.0.1:8080"
    send_http_request() {
        printf '%s\n' "$@" > "$CAPTURE_FILE"
        printf '%s' "$VALID_UAPI_SUCCESS"
        return 0
    }
    send_cpanel_uapi_request "GET" "DomainInfo" "list_domains" >/dev/null
)
STATUS=$?
load_captured_args "$CAPTURE_FILE"
rm -f "$CAPTURE_FILE"

if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0, got $STATUS"
elif [[ "${CAPTURED_ARGS[1]}" != "http://127.0.0.1:8080" ]]; then
    test_fail "Expected explicit base_url 'http://127.0.0.1:8080', got '${CAPTURED_ARGS[1]}'"
else
    test_pass "Explicit http:// CPANEL_HOST preserved accurately."
fi

# ========================================================================
# 4. Response Pipeline & Error Propagation
# ========================================================================

test_header "send_cpanel_uapi_request (Failure expected - HTTP transport failure in send_http_request)"
STDOUT_OUTPUT="$(
    set_valid_cpanel_env
    send_http_request() {
        return 1
    }
    send_cpanel_uapi_request "GET" "Email" "list_pops" 2>/dev/null
)"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success when send_http_request failed"
elif [[ -n "$STDOUT_OUTPUT" ]]; then
    test_fail "Expected empty stdout on transport failure, got: '$STDOUT_OUTPUT'"
else
    test_pass "HTTP transport failure propagated cleanly with no stdout leakage."
fi

test_header "send_cpanel_uapi_request (Failure expected - cPanel application error status: 0)"
COMBINED_OUTPUT="$(
    set_valid_cpanel_env
    send_http_request() {
        printf '%s' "$VALID_UAPI_APP_ERROR"
        return 0
    }
    send_cpanel_uapi_request "GET" "Email" "list_pops" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success on cPanel status: 0 response"
elif [[ "$COMBINED_OUTPUT" != *"Access denied"* ]]; then
    test_fail "Expected extracted UAPI error 'Access denied' in output, got: $COMBINED_OUTPUT"
else
    test_pass "Application-level error (status: 0) caught and surfaced."
fi

test_header "send_cpanel_uapi_request (Failure expected - non-JSON HTML response from server)"
COMBINED_OUTPUT="$(
    set_valid_cpanel_env
    send_http_request() {
        printf '%s' '<html><body>502 Bad Gateway</body></html>'
        return 0
    }
    send_cpanel_uapi_request "GET" "Email" "list_pops" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success on HTML 502 response"
elif [[ "$COMBINED_OUTPUT" != *"non-JSON or malformed JSON"* ]]; then
    test_fail "Expected malformed JSON error message, got: $COMBINED_OUTPUT"
else
    test_pass "Non-JSON HTML response rejected cleanly."
fi

# ========================================================================
# 5. Secret Redaction under Verbose Logging
# ========================================================================

test_header "send_cpanel_uapi_request (Security - CPANEL_TOKEN never appears in verbose stderr logs)"
VERBOSE_LOGS="$(
    set_valid_cpanel_env
    export VERBOSE=1
    send_http_request() {
        printf '%s' "$VALID_UAPI_SUCCESS"
        return 0
    }
    send_cpanel_uapi_request "GET" "Email" "list_pops" 2>&1 >/dev/null
)"
STATUS=$?
if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0 under VERBOSE=1, got $STATUS"
elif [[ "$VERBOSE_LOGS" == *"super_secret_token_98765"* ]]; then
    test_fail "SECURITY FAILURE: CPANEL_TOKEN leaked in verbose logs!"
elif [[ "$VERBOSE_LOGS" != *"CPANEL_TOKEN=*****"* ]]; then
    test_fail "Expected redacted token placeholder in verbose logs, got: $VERBOSE_LOGS"
else
    test_pass "CPANEL_TOKEN properly redacted in verbose logs."
fi

echo "------------------------------------------------"
echo "All send_cpanel_uapi_request tests completed."