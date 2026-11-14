#!/usr/bin/env bash

# ========================================================================
# Test script for build_curl_params in http.sh
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

echo "Running build_curl_params tests..."
echo "------------------------------------------------"

# 1. Happy Cases: Standard formatting & eval round-trip deserialization
test_header "Happy Case: Single standard parameter"
RAW_OUT=$(build_curl_params "domain=example.com")
eval "PARSED_ARGS=(${RAW_OUT})"
assert_test_equals "2" "${#PARSED_ARGS[@]}"
assert_test_equals "--data-urlencode" "${PARSED_ARGS[0]}"
assert_test_equals "domain=example.com" "${PARSED_ARGS[1]}"

test_header "Happy Case: Multiple parameters preserve order and values"
RAW_OUT=$(build_curl_params "domain=example.com" "email=admin@example.com" "quota=500")
eval "PARSED_ARGS=(${RAW_OUT})"
assert_test_equals "6" "${#PARSED_ARGS[@]}"
assert_test_equals "--data-urlencode" "${PARSED_ARGS[0]}"
assert_test_equals "domain=example.com" "${PARSED_ARGS[1]}"
assert_test_equals "--data-urlencode" "${PARSED_ARGS[2]}"
assert_test_equals "email=admin@example.com" "${PARSED_ARGS[3]}"
assert_test_equals "--data-urlencode" "${PARSED_ARGS[4]}"
assert_test_equals "quota=500" "${PARSED_ARGS[5]}"

# 2. Corner Conditions
test_header "Corner Condition: Zero arguments returns empty output and exits 0"
RAW_OUT=$(build_curl_params)
EXIT_CODE=$?
assert_test_equals "0" "$EXIT_CODE"
assert_test_equals "" "$RAW_OUT"

test_header "Corner Condition: Parameter with empty value"
RAW_OUT=$(build_curl_params "empty_key=")
eval "PARSED_ARGS=(${RAW_OUT})"
assert_test_equals "2" "${#PARSED_ARGS[@]}"
assert_test_equals "--data-urlencode" "${PARSED_ARGS[0]}"
assert_test_equals "empty_key=" "${PARSED_ARGS[1]}"

test_header "Corner Condition: Parameter value containing additional '=' signs (e.g., Base64 token)"
RAW_OUT=$(build_curl_params "token=abc123def==")
eval "PARSED_ARGS=(${RAW_OUT})"
assert_test_equals "2" "${#PARSED_ARGS[@]}"
assert_test_equals "--data-urlencode" "${PARSED_ARGS[0]}"
assert_test_equals "token=abc123def==" "${PARSED_ARGS[1]}"

test_header "Corner Condition: Parameter value containing spaces, quotes, and shell metacharacters"
RAW_OUT=$(build_curl_params "note=hello world; \$baz 'qux' \"quux\" & *")
eval "PARSED_ARGS=(${RAW_OUT})"
assert_test_equals "2" "${#PARSED_ARGS[@]}"
assert_test_equals "--data-urlencode" "${PARSED_ARGS[0]}"
assert_test_equals "note=hello world; \$baz 'qux' \"quux\" & *" "${PARSED_ARGS[1]}"

test_header "Corner Condition: Parameter value containing embedded newlines"
MULTILINE_PARAM=$'body=line one\nline two'
RAW_OUT=$(build_curl_params "$MULTILINE_PARAM")
eval "PARSED_ARGS=(${RAW_OUT})"
assert_test_equals "2" "${#PARSED_ARGS[@]}"
assert_test_equals "--data-urlencode" "${PARSED_ARGS[0]}"
assert_test_equals "$MULTILINE_PARAM" "${PARSED_ARGS[1]}"

# 3. Pre-condition & Argument Assertions (Expected Failures)
test_header "Pre-condition: Empty string argument (Failure case expected)"
if ( build_curl_params "" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected empty parameter)"
else
    test_pass "Failure caught successfully."
fi

test_header "Pre-condition: Whitespace-only parameter (Failure case expected)"
if ( build_curl_params "   " > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected whitespace-only parameter)"
else
    test_pass "Failure caught successfully."
fi

test_header "Pre-condition: Missing '=' separator (Failure case expected)"
if ( build_curl_params "domain_without_value" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected parameter missing '=')"
else
    test_pass "Failure caught successfully."
fi

test_header "Pre-condition: Empty key before '=' (Failure case expected)"
if ( build_curl_params "=orphan_value" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected empty key)"
else
    test_pass "Failure caught successfully."
fi

test_header "Pre-condition: Whitespace inside parameter key (Failure case expected)"
if ( build_curl_params "bad key=value" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected whitespace in parameter key)"
else
    test_pass "Failure caught successfully."
fi

test_header "Pre-condition: Leading whitespace before parameter key (Failure case expected)"
if ( build_curl_params " domain=example.com" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected leading whitespace)"
else
    test_pass "Failure caught successfully."
fi

test_header "Pre-condition: Tab or newline inside parameter key (Failure case expected)"
if ( build_curl_params $'bad\nkey=value' > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected newline in parameter key)"
else
    test_pass "Failure caught successfully."
fi

test_header "Pre-condition: Invalid second parameter fails even when first parameter is valid (Failure case expected)"
if ( build_curl_params "domain=example.com" "InvalidParam" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected invalid subsequent parameter)"
else
    test_pass "Failure caught successfully."
fi

echo "------------------------------------------------"
echo "All tests completed."