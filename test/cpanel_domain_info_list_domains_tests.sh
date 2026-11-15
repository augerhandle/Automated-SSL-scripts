#!/usr/bin/env bash

# ========================================================================
# Test script for cpanel_domain_info_list_domains in cpanel_domain_info.sh
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
source "${LIB_DIR}/http.sh"
source "${LIB_DIR}/cpanel.sh"
source "${LIB_DIR}/cpanel_domain_info.sh"
source "${TEST_DIR}/test_helpers.sh"

# ------------------------------------------------------------------------
# Test Fixtures & Helpers
# ------------------------------------------------------------------------

VALID_LIST_DOMAINS_RESPONSE='{
  "status": 1,
  "errors": null,
  "messages": null,
  "data": {
    "main_domain": "example.com",
    "addon_domains": ["addon1.org", "addon2.net"],
    "sub_domains": ["blog.example.com", "api.example.com"],
    "parked_domains": ["alias.example.com"]
  }
}'

EMPTY_ARRAYS_LIST_DOMAINS_RESPONSE='{
  "status": 1,
  "errors": null,
  "messages": null,
  "data": {
    "main_domain": "primary.example.com",
    "addon_domains": [],
    "sub_domains": [],
    "parked_domains": []
  }
}'

set_valid_cpanel_env() {
    export CPANEL_HOST="cpanel.example.com"
    export CPANEL_USER="testuser"
    export CPANEL_TOKEN="super_secret_token_98765"
    unset CPANEL_PORT
}

# Sentinel mock: fails immediately if send_cpanel_uapi_request is reached
mock_uapi_should_not_run() {
    send_cpanel_uapi_request() {
        echo "MOCK_UAPI_CALLED_UNEXPECTEDLY" >&2
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

echo "Running cpanel_domain_info_list_domains tests..."
echo "------------------------------------------------"

# ========================================================================
# 1. Include Guard & Function Export Verification
# ========================================================================

test_header "cpanel_domain_info.sh (Include guard & function definition)"
if ! declare -F cpanel_domain_info_list_domains >/dev/null 2>&1; then
    test_fail "cpanel_domain_info_list_domains is not defined after sourcing cpanel_domain_info.sh"
elif [[ "${_DAH_CPANEL_DOMAIN_INFO_SH:-}" != "1" ]]; then
    test_fail "Expected _DAH_CPANEL_DOMAIN_INFO_SH=1, got '${_DAH_CPANEL_DOMAIN_INFO_SH:-}'"
else
    source "${LIB_DIR}/cpanel_domain_info.sh"
    test_pass "Function defined and include guard idempotent."
fi

# ========================================================================
# 2. Pre-Condition & Argument Validation
# ========================================================================

test_header "cpanel_domain_info_list_domains (Failure expected - unexpected positional argument)"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    mock_uapi_should_not_run
    cpanel_domain_info_list_domains "unexpected_arg" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success when passing an extra argument"
elif [[ "$ERR_OUTPUT" == *"MOCK_UAPI_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "send_cpanel_uapi_request was called despite unexpected arguments"
else
    test_pass "Unexpected positional argument rejected before UAPI request."
fi

test_header "cpanel_domain_info_list_domains (Failure expected - multiple unexpected arguments)"
ERR_OUTPUT="$(
    set_valid_cpanel_env
    mock_uapi_should_not_run
    cpanel_domain_info_list_domains "domain=example.com" "extra=1" 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 || "$ERR_OUTPUT" == *"MOCK_UAPI_CALLED_UNEXPECTEDLY"* ]]; then
    test_fail "Multiple unexpected arguments were not rejected before UAPI request"
else
    test_pass "Multiple unexpected arguments rejected before UAPI request."
fi

# ========================================================================
# 3. UAPI Argument Forwarding & .data Extraction via jq
# ========================================================================

test_header "cpanel_domain_info_list_domains (Success - forwards GET DomainInfo/list_domains and extracts .data)"
CAPTURE_FILE="$(mktemp)"
STDOUT_OUTPUT="$(
    set_valid_cpanel_env
    send_cpanel_uapi_request() {
        printf '%s\n' "$@" > "$CAPTURE_FILE"
        printf '%s\n' "$VALID_LIST_DOMAINS_RESPONSE"
        return 0
    }
    cpanel_domain_info_list_domains
)"
STATUS=$?
load_captured_args "$CAPTURE_FILE"
rm -f "$CAPTURE_FILE"

if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0, got $STATUS"
elif [[ "${#CAPTURED_ARGS[@]}" -ne 3 ]]; then
    test_fail "Expected exactly 3 arguments passed to send_cpanel_uapi_request, got ${#CAPTURED_ARGS[@]}"
elif [[ "${CAPTURED_ARGS[0]}" != "GET" ]]; then
    test_fail "Expected HTTP_METHOD 'GET', got '${CAPTURED_ARGS[0]}'"
elif [[ "${CAPTURED_ARGS[1]}" != "DomainInfo" ]]; then
    test_fail "Expected MODULE 'DomainInfo', got '${CAPTURED_ARGS[1]}'"
elif [[ "${CAPTURED_ARGS[2]}" != "list_domains" ]]; then
    test_fail "Expected FUNCTION 'list_domains', got '${CAPTURED_ARGS[2]}'"
elif ! printf '%s' "$STDOUT_OUTPUT" | jq -e 'type == "object" and (has("status") | not) and has("main_domain")' >/dev/null 2>&1; then
    test_fail "Expected unwrapped .data object on stdout, got: '$STDOUT_OUTPUT'"
elif [[ "$(printf '%s' "$STDOUT_OUTPUT" | jq -r '.main_domain')" != "example.com" ]]; then
    test_fail "Expected main_domain 'example.com', got '$(printf '%s' "$STDOUT_OUTPUT" | jq -r '.main_domain')'"
elif [[ "$(printf '%s' "$STDOUT_OUTPUT" | jq -r '.addon_domains | length')" != "2" ]]; then
    test_fail "Expected 2 addon_domains, got '$(printf '%s' "$STDOUT_OUTPUT" | jq -r '.addon_domains | length')'"
elif [[ "$(printf '%s' "$STDOUT_OUTPUT" | jq -r '.sub_domains[0]')" != "blog.example.com" ]]; then
    test_fail "Expected sub_domains[0] 'blog.example.com', got '$(printf '%s' "$STDOUT_OUTPUT" | jq -r '.sub_domains[0]')'"
elif [[ "$(printf '%s' "$STDOUT_OUTPUT" | jq -r '.parked_domains[0]')" != "alias.example.com" ]]; then
    test_fail "Expected parked_domains[0] 'alias.example.com', got '$(printf '%s' "$STDOUT_OUTPUT" | jq -r '.parked_domains[0]')'"
else
    test_pass "Forwarded GET DomainInfo list_domains with 0 params and extracted .data object cleanly."
fi

test_header "cpanel_domain_info_list_domains (Success - account with empty addon/sub/parked arrays)"
STDOUT_OUTPUT="$(
    set_valid_cpanel_env
    send_cpanel_uapi_request() {
        printf '%s\n' "$EMPTY_ARRAYS_LIST_DOMAINS_RESPONSE"
        return 0
    }
    cpanel_domain_info_list_domains
)"
STATUS=$?
if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0, got $STATUS"
elif [[ "$(printf '%s' "$STDOUT_OUTPUT" | jq -r '.main_domain')" != "primary.example.com" ]]; then
    test_fail "Expected main_domain 'primary.example.com', got: '$STDOUT_OUTPUT'"
elif [[ "$(printf '%s' "$STDOUT_OUTPUT" | jq -r '.addon_domains | length')" != "0" ]]; then
    test_fail "Expected 0 addon_domains, got: '$STDOUT_OUTPUT'"
else
    test_pass "Handled empty domain category arrays cleanly."
fi

# ========================================================================
# 4. Error Propagation & Malformed .data Rejection
# ========================================================================

test_header "cpanel_domain_info_list_domains (Failure expected - send_cpanel_uapi_request failure)"
STDOUT_OUTPUT="$(
    set_valid_cpanel_env
    send_cpanel_uapi_request() {
        return 1
    }
    cpanel_domain_info_list_domains 2>/dev/null
)"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success when send_cpanel_uapi_request failed"
elif [[ -n "$STDOUT_OUTPUT" ]]; then
    test_fail "Expected empty stdout on UAPI failure, got: '$STDOUT_OUTPUT'"
else
    test_pass "UAPI transport/application failure propagated cleanly with no stdout output."
fi

test_header "cpanel_domain_info_list_domains (Failure expected - null .data payload)"
COMBINED_OUTPUT="$(
    set_valid_cpanel_env
    send_cpanel_uapi_request() {
        printf '%s\n' '{"status": 1, "errors": null, "messages": null, "data": null}'
        return 0
    }
    cpanel_domain_info_list_domains 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success when .data was null"
elif [[ "$COMBINED_OUTPUT" != *"invalid or non-object 'data' payload"* ]]; then
    test_fail "Expected non-object 'data' payload error message, got: '$COMBINED_OUTPUT'"
else
    test_pass "Null .data payload rejected cleanly."
fi

test_header "cpanel_domain_info_list_domains (Failure expected - array .data instead of object)"
COMBINED_OUTPUT="$(
    set_valid_cpanel_env
    send_cpanel_uapi_request() {
        printf '%s\n' '{"status": 1, "errors": null, "messages": null, "data": ["unexpected_array"]}'
        return 0
    }
    cpanel_domain_info_list_domains 2>&1
)"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success when .data was an array"
elif [[ "$COMBINED_OUTPUT" != *"invalid or non-object 'data' payload"* ]]; then
    test_fail "Expected non-object 'data' payload error message, got: '$COMBINED_OUTPUT'"
else
    test_pass "Non-object array .data payload rejected cleanly."
fi

# ========================================================================
# 5. Secret Redaction under Verbose Logging
# ========================================================================

test_header "cpanel_domain_info_list_domains (Security - CPANEL_TOKEN redacted under VERBOSE=1)"
VERBOSE_LOGS="$(
    set_valid_cpanel_env
    export VERBOSE=1
    send_http_request() {
        printf '%s' "$VALID_LIST_DOMAINS_RESPONSE"
        return 0
    }
    cpanel_domain_info_list_domains 2>&1 >/dev/null
)"
STATUS=$?
if [[ $STATUS -ne 0 ]]; then
    test_fail "Expected exit status 0 under VERBOSE=1, got $STATUS"
elif [[ "$VERBOSE_LOGS" == *"super_secret_token_98765"* ]]; then
    test_fail "SECURITY FAILURE: CPANEL_TOKEN leaked in verbose logs!"
elif [[ "$VERBOSE_LOGS" != *"CPANEL_TOKEN=*****"* ]]; then
    test_fail "Expected redacted CPANEL_TOKEN=***** placeholder in verbose logs, got: $VERBOSE_LOGS"
else
    test_pass "CPANEL_TOKEN properly redacted under VERBOSE=1."
fi

echo "------------------------------------------------"
echo "All cpanel_domain_info_list_domains tests completed."