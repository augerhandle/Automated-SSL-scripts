#!/usr/bin/env bash

# ========================================================================
# Unit test script for send_http_request in http.sh using a mocked curl
# (Tests exact curl CLI flag assembly, status code handling, temp file
#  cleanup, and Authorization header log redaction completely offline)
# ========================================================================

# ------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/assert.sh"
source "${LIB_DIR}/serialize.sh"
source "${LIB_DIR}/http.sh"
source "${TEST_DIR}/test_helpers.sh"

# ------------------------------------------------------------------------
# Test Helpers
# ------------------------------------------------------------------------

# Portable Bash 3.2+ replacement for `mapfile -t CAPTURED_ARGS < "$file"`
load_captured_args() {
    local file="$1"
    CAPTURED_ARGS=()
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        CAPTURED_ARGS+=("$line")
    done < "$file"
}

# Helper to check whether an exact element exists in CAPTURED_ARGS
captured_args_contains() {
    local needle="$1"
    local item
    for item in "${CAPTURED_ARGS[@]}"; do
        if [[ "$item" == "$needle" ]]; then
            return 0
        fi
    done
    return 1
}

# Helper to verify two consecutive elements appear in order in CAPTURED_ARGS
captured_args_contains_pair() {
    local first="$1"
    local second="$2"
    local i
    for (( i=0; i < ${#CAPTURED_ARGS[@]} - 1; i++ )); do
        if [[ "${CAPTURED_ARGS[$i]}" == "$first" && "${CAPTURED_ARGS[$((i+1))]}" == "$second" ]]; then
            return 0
        fi
    done
    return 1
}

# Creates a mock `curl` function that:
#   1. Records every CLI argument received into $ARGS_FILE (one per line)
#   2. Writes $MOCK_BODY into the file passed after `--output`
#   3. Prints $MOCK_STATUS to stdout (simulating `--write-out "%{http_code}"`)
#   4. Returns $MOCK_EXIT_CODE
define_mock_curl() {
    curl() {
        printf '%s\n' "$@" > "$ARGS_FILE"

        local output_file=""
        local prev=""
        local arg
        for arg in "$@"; do
            if [[ "$prev" == "--output" ]]; then
                output_file="$arg"
                break
            fi
            prev="$arg"
        done

        if [[ -n "$output_file" ]]; then
            printf '%s' "$MOCK_BODY" > "$output_file"
        fi

        printf '%s' "$MOCK_STATUS"
        return "${MOCK_EXIT_CODE:-0}"
    }
}

# ------------------------------------------------------------------------
# Test Cases
# ------------------------------------------------------------------------

echo "Running http.sh (send_http_request with mocked curl) tests..."
echo "------------------------------------------------"

# ========================================================================
# 1. Curl CLI Flag Assembly & Argument Serialization
# ========================================================================

test_header "send_http_request (Mocked curl - GET without params omits --get and sends default headers)"
ARGS_FILE="$(mktemp)"
STDOUT_OUTPUT="$(
    MOCK_BODY='{"ok":true}'
    MOCK_STATUS="200"
    MOCK_EXIT_CODE=0
    define_mock_curl
    send_http_request "GET" "api.example.com" "/v1/status" 2>/dev/null
)"
STATUS=$?
load_captured_args "$ARGS_FILE"
rm -f "$ARGS_FILE"

LAST_INDEX=$(( ${#CAPTURED_ARGS[@]} - 1 ))
if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0, got $STATUS"
elif [[ "$STDOUT_OUTPUT" != '{"ok":true}' ]]; then
    test_fail "Unexpected stdout body: '$STDOUT_OUTPUT'"
elif ! captured_args_contains "--silent" || ! captured_args_contains "--show-error"; then
    test_fail "Expected --silent and --show-error flags in curl invocation"
elif ! captured_args_contains_pair "--request" "GET"; then
    test_fail "Expected '--request GET' in curl invocation"
elif ! captured_args_contains_pair "--write-out" "%{http_code}"; then
    test_fail "Expected '--write-out %{http_code}' in curl invocation"
elif ! captured_args_contains_pair "-H" "Accept: application/json"; then
    test_fail "Expected default Accept header in curl invocation"
elif ! captured_args_contains_pair "-H" "User-Agent: Bash-API-Client/1.0"; then
    test_fail "Expected default User-Agent header in curl invocation"
elif captured_args_contains "--get"; then
    test_fail "Did not expect --get flag when no query parameters are provided"
elif [[ "${CAPTURED_ARGS[$LAST_INDEX]}" != "https://api.example.com/v1/status" ]]; then
    test_fail "Expected final argument to be 'https://api.example.com/v1/status', got '${CAPTURED_ARGS[$LAST_INDEX]}'"
else
    test_pass "GET without params assembled exact curl flags and normalized URL."
fi

test_header "send_http_request (Mocked curl - GET with params includes --get and --data-urlencode)"
ARGS_FILE="$(mktemp)"
STDOUT_OUTPUT="$(
    MOCK_BODY='{"items":[1,2]}'
    MOCK_STATUS="200"
    MOCK_EXIT_CODE=0
    define_mock_curl
    send_http_request "GET" "https://api.example.com:8443" "/items" "" "filter=active users" "tag=a&b=c" 2>/dev/null
)"
STATUS=$?
load_captured_args "$ARGS_FILE"
rm -f "$ARGS_FILE"

LAST_INDEX=$(( ${#CAPTURED_ARGS[@]} - 1 ))
if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0, got $STATUS"
elif ! captured_args_contains "--get"; then
    test_fail "Expected --get flag when GET is called with parameters"
elif ! captured_args_contains_pair "--data-urlencode" "filter=active users"; then
    test_fail "Expected '--data-urlencode filter=active users' preserved with spaces"
elif ! captured_args_contains_pair "--data-urlencode" "tag=a&b=c"; then
    test_fail "Expected '--data-urlencode tag=a&b=c' preserved with special characters"
elif [[ "${CAPTURED_ARGS[$LAST_INDEX]}" != "https://api.example.com:8443/items" ]]; then
    test_fail "Expected final URL 'https://api.example.com:8443/items', got '${CAPTURED_ARGS[$LAST_INDEX]}'"
else
    test_pass "GET with params passed --get and serialized --data-urlencode values intact."
fi

test_header "send_http_request (Mocked curl - POST with multiline custom headers and form params omits --get)"
ARGS_FILE="$(mktemp)"
CUSTOM_HEADERS=$'Authorization: cpanel alice:tok123\n\nX-Trace-Id: req-99'
STDOUT_OUTPUT="$(
    MOCK_BODY='{"created":true}'
    MOCK_STATUS="201"
    MOCK_EXIT_CODE=0
    define_mock_curl
    send_http_request "POST" "https://api.example.com" "/users" "$CUSTOM_HEADERS" "name=Alice Smith" "role=admin" 2>/dev/null
)"
STATUS=$?
load_captured_args "$ARGS_FILE"
rm -f "$ARGS_FILE"

if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0 on HTTP 201, got $STATUS"
elif captured_args_contains "--get"; then
    test_fail "POST request must not pass --get to curl"
elif ! captured_args_contains_pair "--request" "POST"; then
    test_fail "Expected '--request POST' in curl invocation"
elif ! captured_args_contains_pair "-H" "Authorization: cpanel alice:tok123"; then
    test_fail "Expected Authorization header passed to curl"
elif ! captured_args_contains_pair "-H" "X-Trace-Id: req-99"; then
    test_fail "Expected X-Trace-Id header passed to curl"
elif ! captured_args_contains_pair "--data-urlencode" "name=Alice Smith"; then
    test_fail "Expected '--data-urlencode name=Alice Smith' passed to curl"
elif ! captured_args_contains_pair "--data-urlencode" "role=admin"; then
    test_fail "Expected '--data-urlencode role=admin' passed to curl"
elif [[ "$STDOUT_OUTPUT" != '{"created":true}' ]]; then
    test_fail "Unexpected stdout body on HTTP 201: '$STDOUT_OUTPUT'"
else
    test_pass "POST assembled headers, form params, and succeeded on HTTP 201."
fi

# ========================================================================
# 2. HTTP Status Edge Cases & Curl Exit Code Handling
# ========================================================================

test_header "send_http_request (Mocked curl - HTTP 204 No Content with empty response body succeeds)"
ARGS_FILE="$(mktemp)"
STDOUT_OUTPUT="$(
    MOCK_BODY=""
    MOCK_STATUS="204"
    MOCK_EXIT_CODE=0
    define_mock_curl
    send_http_request "DELETE" "https://api.example.com" "/users/42" 2>/dev/null
)"
STATUS=$?
rm -f "$ARGS_FILE"

if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0 on HTTP 204, got $STATUS"
elif [[ -n "$STDOUT_OUTPUT" ]]; then
    test_fail "Expected empty stdout on HTTP 204, got: '$STDOUT_OUTPUT'"
else
    test_pass "HTTP 204 No Content handled cleanly."
fi

test_header "send_http_request (Mocked curl - HTTP 401/502 error fails and does not leak body to stdout)"
ARGS_FILE="$(mktemp)"
STDOUT_OUTPUT="$(
    MOCK_BODY='<html><body>502 Bad Gateway</body></html>'
    MOCK_STATUS="502"
    MOCK_EXIT_CODE=0
    define_mock_curl
    send_http_request "GET" "https://api.example.com" "/v1/data" 2>/dev/null
)"
STATUS=$?
rm -f "$ARGS_FILE"

if [[ $STATUS -eq 0 ]]; then
    test_fail "Expected non-zero exit status on HTTP 502"
elif [[ -n "$STDOUT_OUTPUT" ]]; then
    test_fail "Expected no stdout output on HTTP 502 failure, got: '$STDOUT_OUTPUT'"
else
    test_pass "HTTP 502 error rejected cleanly with no stdout leakage."
fi

test_header "send_http_request (Mocked curl - non-zero curl exit code 28 fails even if status is 000)"
ARGS_FILE="$(mktemp)"
STDOUT_OUTPUT="$(
    MOCK_BODY=""
    MOCK_STATUS="000"
    MOCK_EXIT_CODE=28
    define_mock_curl
    send_http_request "GET" "https://api.example.com" "/v1/slow" 2>/dev/null
)"
STATUS=$?
rm -f "$ARGS_FILE"

if [[ $STATUS -eq 0 ]]; then
    test_fail "Expected non-zero exit status when curl exits with 28 (timeout)"
elif [[ -n "$STDOUT_OUTPUT" ]]; then
    test_fail "Expected empty stdout on curl exit 28, got: '$STDOUT_OUTPUT'"
else
    test_pass "Curl exit code 28 failure caught cleanly."
fi

# ========================================================================
# 3. Temp File Cleanup & Authorization Header Redaction
# ========================================================================

test_header "send_http_request (Mocked curl - temporary --output file is removed after request)"
ARGS_FILE="$(mktemp)"
(
    MOCK_BODY='{"ok":true}'
    MOCK_STATUS="200"
    MOCK_EXIT_CODE=0
    define_mock_curl
    send_http_request "GET" "https://api.example.com" "/v1/ping" >/dev/null 2>&1
)
load_captured_args "$ARGS_FILE"
rm -f "$ARGS_FILE"

TEMP_BODY_PATH=""
for (( i=0; i < ${#CAPTURED_ARGS[@]} - 1; i++ )); do
    if [[ "${CAPTURED_ARGS[$i]}" == "--output" ]]; then
        TEMP_BODY_PATH="${CAPTURED_ARGS[$((i+1))]}"
        break
    fi
done

if [[ -z "$TEMP_BODY_PATH" ]]; then
    test_fail "Could not find --output path in captured curl arguments"
elif [[ -e "$TEMP_BODY_PATH" ]]; then
    rm -f "$TEMP_BODY_PATH"
    test_fail "Temporary response body file was leaked on disk: $TEMP_BODY_PATH"
else
    test_pass "Temporary response body file was cleaned up properly."
fi

test_header "send_http_request (Mocked curl - Authorization header is redacted in verbose stderr logs)"
ARGS_FILE="$(mktemp)"
VERBOSE_LOGS="$(
    export VERBOSE=1
    MOCK_BODY='{"ok":true}'
    MOCK_STATUS="200"
    MOCK_EXIT_CODE=0
    define_mock_curl
    send_http_request "GET" "https://api.example.com" "/v1/secure" "Authorization: cpanel myuser:top_secret_api_token" 2>&1 >/dev/null
)"
STATUS=$?
rm -f "$ARGS_FILE"

if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0 under VERBOSE=1, got $STATUS"
elif [[ "$VERBOSE_LOGS" == *"top_secret_api_token"* ]]; then
    test_fail "SECURITY FAILURE: Authorization token leaked in verbose logs!"
elif [[ "$VERBOSE_LOGS" != *"header=Authorization: *****"* ]]; then
    test_fail "Expected redacted 'header=Authorization: *****' in verbose logs, got: $VERBOSE_LOGS"
else
    test_pass "Authorization header properly redacted in verbose logs."
fi

echo "------------------------------------------------"
echo "All send_http_request (mocked curl) tests completed."