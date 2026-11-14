#!/usr/bin/env bash

# ========================================================================
# Test script for serialize.sh
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
source "${LIB_DIR}/serialize.sh"
source "${TEST_DIR}/test_helpers.sh"

# ------------------------------------------------------------------------
# Test Cases
# ------------------------------------------------------------------------

echo "Running serialize.sh tests..."
echo "------------------------------------------------"

# 1. Happy Cases: serialize_args formatting
echo "[TEST] Happy Case (serialize_args): Single simple argument"
RESULT=$(serialize_args "simple")
EXPECTED=$(printf '%q ' "simple")
assert_test_equals "$EXPECTED" "$RESULT"

echo "[TEST] Happy Case (serialize_args): Multiple arguments preserve order and spacing"
RESULT=$(serialize_args "Accept: application/json" "Authorization: cpanel user:token123" "User-Agent: Bash-API-Client/1.0")
EXPECTED=$(printf '%q ' "Accept: application/json" "Authorization: cpanel user:token123" "User-Agent: Bash-API-Client/1.0")
assert_test_equals "$EXPECTED" "$RESULT"

# 2. Happy Cases: Round-trip (serialize_args -> deserialize_args)
echo "[TEST] Happy Case (round-trip): Multiple standard strings preserve count, order, and spaces"
SERIALIZED_STRING=$(serialize_args "first item" "second item" "third_item")
DESERIALIZED_ARGS=()
deserialize_args DESERIALIZED_ARGS "$SERIALIZED_STRING"
assert_test_equals "3" "${#DESERIALIZED_ARGS[@]}"
assert_test_equals "first item" "${DESERIALIZED_ARGS[0]}"
assert_test_equals "second item" "${DESERIALIZED_ARGS[1]}"
assert_test_equals "third_item" "${DESERIALIZED_ARGS[2]}"

echo "[TEST] Happy Case (round-trip): Overwrites pre-existing elements in destination array"
SERIALIZED_STRING=$(serialize_args "fresh_value")
DESERIALIZED_ARGS=("stale_one" "stale_two")
deserialize_args DESERIALIZED_ARGS "$SERIALIZED_STRING"
assert_test_equals "1" "${#DESERIALIZED_ARGS[@]}"
assert_test_equals "fresh_value" "${DESERIALIZED_ARGS[0]}"

# 3. Corner Conditions
echo "[TEST] Corner Condition (serialize_args): Zero arguments returns empty output and exits 0"
RESULT=$(serialize_args)
EXIT_CODE=$?
assert_test_equals "0" "$EXIT_CODE"
assert_test_equals "" "$RESULT"

echo "[TEST] Corner Condition (deserialize_args): Empty string yields empty array"
DESERIALIZED_ARGS=("stale_item")
deserialize_args DESERIALIZED_ARGS ""
assert_test_equals "0" "${#DESERIALIZED_ARGS[@]}"

echo "[TEST] Corner Condition (deserialize_args): Whitespace-only string yields empty array"
DESERIALIZED_ARGS=("stale_item")
deserialize_args DESERIALIZED_ARGS "   "
assert_test_equals "0" "${#DESERIALIZED_ARGS[@]}"

echo "[TEST] Corner Condition (round-trip): Single empty string element is preserved"
SERIALIZED_STRING=$(serialize_args "")
DESERIALIZED_ARGS=()
deserialize_args DESERIALIZED_ARGS "$SERIALIZED_STRING"
assert_test_equals "1" "${#DESERIALIZED_ARGS[@]}"
assert_test_equals "" "${DESERIALIZED_ARGS[0]}"

echo "[TEST] Corner Condition (round-trip): Empty string elements mixed with non-empty elements"
SERIALIZED_STRING=$(serialize_args "" "middle" "")
DESERIALIZED_ARGS=()
deserialize_args DESERIALIZED_ARGS "$SERIALIZED_STRING"
assert_test_equals "3" "${#DESERIALIZED_ARGS[@]}"
assert_test_equals "" "${DESERIALIZED_ARGS[0]}"
assert_test_equals "middle" "${DESERIALIZED_ARGS[1]}"
assert_test_equals "" "${DESERIALIZED_ARGS[2]}"

echo "[TEST] Corner Condition (round-trip): Shell metacharacters, quotes, globs, and command substitutions are treated as literals"
TRICKY_STR="foo:bar; \$HOME \$(echo pwned) 'single' \"double\" & * ? [a-z]"
SERIALIZED_STRING=$(serialize_args "$TRICKY_STR")
DESERIALIZED_ARGS=()
deserialize_args DESERIALIZED_ARGS "$SERIALIZED_STRING"
assert_test_equals "1" "${#DESERIALIZED_ARGS[@]}"
assert_test_equals "$TRICKY_STR" "${DESERIALIZED_ARGS[0]}"

echo "[TEST] Corner Condition (round-trip): Embedded newlines and tabs are preserved"
MULTILINE_STR=$'line one\n\tline two\nline three'
SERIALIZED_STRING=$(serialize_args "$MULTILINE_STR" "second_arg")
DESERIALIZED_ARGS=()
deserialize_args DESERIALIZED_ARGS "$SERIALIZED_STRING"
assert_test_equals "2" "${#DESERIALIZED_ARGS[@]}"
assert_test_equals "$MULTILINE_STR" "${DESERIALIZED_ARGS[0]}"
assert_test_equals "second_arg" "${DESERIALIZED_ARGS[1]}"

# 4. Pre-condition & Argument Assertions (Expected Failures)
echo "[TEST] Pre-condition (deserialize_args): Missing arguments (Failure case expected)"
if ( deserialize_args DESERIALIZED_ARGS > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected 1 argument)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition (deserialize_args): Too many arguments (Failure case expected)"
if ( deserialize_args DESERIALIZED_ARGS "a" "b" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected 3 arguments)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition (deserialize_args): Empty target variable name (Failure case expected)"
if ( deserialize_args "" "foo" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected empty variable name)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition (deserialize_args): Numeric-leading variable name (Failure case expected)"
if ( deserialize_args "1invalid" "foo" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected variable name starting with digit)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition (deserialize_args): Variable name with injection characters (Failure case expected)"
if ( deserialize_args "ARR=(); echo pwned; X" "foo" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected invalid variable identifier)"
else
    test_pass "Failure caught successfully."
fi

echo "------------------------------------------------"
echo "All tests completed."