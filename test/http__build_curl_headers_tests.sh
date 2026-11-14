#!/usr/bin/env bash

# ========================================================================
# Test script for build_curl_headers in http.sh
# ========================================================================

# ------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------

# Resolve paths relative to this test script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Source libraries and co-located test helpers
source "${LIB_DIR}/assert.sh"
source "${LIB_DIR}/http.sh"
source "${TEST_DIR}/test_helpers.sh"

# ------------------------------------------------------------------------
# Test Cases
# ------------------------------------------------------------------------

echo "Running build_curl_headers tests..."
echo "------------------------------------------------"

# 1. Happy Cases: Standard formatting & eval round-trip deserialization
echo "[TEST] Happy Case: Single standard header"
RAW_OUT=$(build_curl_headers "Accept: application/json")
eval "PARSED_ARGS=(${RAW_OUT})"
assert_test_equals "2" "${#PARSED_ARGS[@]}"
assert_test_equals "-H" "${PARSED_ARGS[0]}"
assert_test_equals "Accept: application/json" "${PARSED_ARGS[1]}"

echo "[TEST] Happy Case: Multiple headers preserve order and spacing"
RAW_OUT=$(build_curl_headers "Accept: application/json" "Authorization: cpanel user:token123" "User-Agent: Bash-API-Client/1.0")
eval "PARSED_ARGS=(${RAW_OUT})"
assert_test_equals "6" "${#PARSED_ARGS[@]}"
assert_test_equals "-H" "${PARSED_ARGS[0]}"
assert_test_equals "Accept: application/json" "${PARSED_ARGS[1]}"
assert_test_equals "-H" "${PARSED_ARGS[2]}"
assert_test_equals "Authorization: cpanel user:token123" "${PARSED_ARGS[3]}"
assert_test_equals "-H" "${PARSED_ARGS[4]}"
assert_test_equals "User-Agent: Bash-API-Client/1.0" "${PARSED_ARGS[5]}"

# 2. Corner Conditions
echo "[TEST] Corner Condition: Zero arguments returns empty output and exits 0"
RAW_OUT=$(build_curl_headers)
EXIT_CODE=$?
assert_test_equals "0" "$EXIT_CODE"
assert_test_equals "" "$RAW_OUT"

echo "[TEST] Corner Condition: Header with no space after colon"
RAW_OUT=$(build_curl_headers "X-Custom:value")
eval "PARSED_ARGS=(${RAW_OUT})"
assert_test_equals "2" "${#PARSED_ARGS[@]}"
assert_test_equals "X-Custom:value" "${PARSED_ARGS[1]}"

echo "[TEST] Corner Condition: Header with empty value (curl header suppression syntax)"
RAW_OUT=$(build_curl_headers "X-Empty:")
eval "PARSED_ARGS=(${RAW_OUT})"
assert_test_equals "2" "${#PARSED_ARGS[@]}"
assert_test_equals "X-Empty:" "${PARSED_ARGS[1]}"

echo "[TEST] Corner Condition: Header value containing colons, quotes, and shell metacharacters"
RAW_OUT=$(build_curl_headers "X-Complex: foo:bar; \$baz 'qux' \"quux\" & *")
eval "PARSED_ARGS=(${RAW_OUT})"
assert_test_equals "2" "${#PARSED_ARGS[@]}"
assert_test_equals "-H" "${PARSED_ARGS[0]}"
assert_test_equals "X-Complex: foo:bar; \$baz 'qux' \"quux\" & *" "${PARSED_ARGS[1]}"

# 3. Pre-condition & Argument Assertions (Expected Failures)
echo "[TEST] Pre-condition: Empty string argument (Failure case expected)"
if ( build_curl_headers "" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected empty header)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Whitespace-only header (Failure case expected)"
if ( build_curl_headers "   " > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected whitespace-only header)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Missing colon separator (Failure case expected)"
if ( build_curl_headers "Authorization cpanel user:token" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected header missing colon)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Empty header name before colon (Failure case expected)"
if ( build_curl_headers ": application/json" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected empty header name)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Whitespace inside header name (Failure case expected)"
if ( build_curl_headers "Bad Header: value" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected whitespace in header name)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Leading whitespace before header name (Failure case expected)"
if ( build_curl_headers " Accept: application/json" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected leading whitespace)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Embedded LF newline injection (Failure case expected)"
if ( build_curl_headers $'Accept: application/json\nX-Injected: evil' > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected LF newline in header)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Embedded CR carriage return injection (Failure case expected)"
if ( build_curl_headers $'Accept: application/json\rX-Injected: evil' > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected CR character in header)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Invalid second header fails even when first header is valid (Failure case expected)"
if ( build_curl_headers "Accept: application/json" "InvalidHeader" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected invalid subsequent header)"
else
    test_pass "Failure caught successfully."
fi

echo "------------------------------------------------"
echo "All tests completed."