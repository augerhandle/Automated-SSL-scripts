#!/usr/bin/env bash

# ========================================================================
# Test script for build_url in http.sh
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
# test cases
# ------------------------------------------------------------------------

echo "Running build_url tests..."
echo "------------------------------------------------"

# 1. Happy Cases: Standard formatting
echo "[TEST] Happy Case: No extra slashes"
RESULT=$(build_url "https://api.example.com" "v1/users")
assert_test_equals "https://api.example.com/v1/users" "$RESULT"

echo "[TEST] Happy Case: Trailing slash on base URL only"
RESULT=$(build_url "https://api.example.com/" "v1/users")
assert_test_equals "https://api.example.com/v1/users" "$RESULT"

echo "[TEST] Happy Case: Leading slash on endpoint only"
RESULT=$(build_url "https://api.example.com" "/v1/users")
assert_test_equals "https://api.example.com/v1/users" "$RESULT"

echo "[TEST] Happy Case: Slashes on both base URL and endpoint"
RESULT=$(build_url "https://api.example.com/" "/v1/users")
assert_test_equals "https://api.example.com/v1/users" "$RESULT"

# 2. Protocol / Scheme Handling
echo "[TEST] Scheme Handling: Missing scheme prepends https://"
RESULT=$(build_url "api.example.com" "/v1/users")
assert_test_equals "https://api.example.com/v1/users" "$RESULT"

echo "[TEST] Scheme Handling: Missing scheme with trailing slash on base URL"
RESULT=$(build_url "api.example.com/" "v1/users")
assert_test_equals "https://api.example.com/v1/users" "$RESULT"

echo "[TEST] Scheme Handling: Explicit http:// scheme is preserved"
RESULT=$(build_url "http://localhost:8080" "/v1/users")
assert_test_equals "http://localhost:8080/v1/users" "$RESULT"

# 3. Corner Conditions
echo "[TEST] Corner Condition: Empty endpoint"
RESULT=$(build_url "https://api.example.com" "")
assert_test_equals "https://api.example.com/" "$RESULT"

echo "[TEST] Corner Condition: Missing scheme with empty endpoint"
RESULT=$(build_url "api.example.com" "")
assert_test_equals "https://api.example.com/" "$RESULT"

echo "[TEST] Corner Condition: Sub-paths with multiple slashes in endpoint"
RESULT=$(build_url "https://api.example.com/" "/v1/users/profile/details/")
assert_test_equals "https://api.example.com/v1/users/profile/details/" "$RESULT"

# 4. Pre-condition & Argument Assertions (Expected Failures)
echo "[TEST] Pre-condition: Missing arguments (Failure case expected)"
# Run in subshell to prevent assert_argc from exiting the test script
if ( build_url "https://api.example.com" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected 1 argument)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Too many arguments (Failure case expected)"
if ( build_url "https://api.example.com" "/v1/users" "extra_arg" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected 3 arguments)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Empty base_url (Failure case expected)"
if ( build_url "" "/v1/users" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected empty base_url)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Whitespace-only base_url (Failure case expected)"
if ( build_url "   " "/v1/users" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected whitespace-only base_url)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Whitespace inside base_url (Failure case expected)"
if ( build_url "https://api.example .com" "/v1/users" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected whitespace in base_url)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Bare https:// scheme without host (Failure case expected)"
if ( build_url "https://" "/v1/users" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected bare https://)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Bare http:// scheme without host (Failure case expected)"
if ( build_url "http://" "/v1/users" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected bare http://)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Slash-only base_url without host (Failure case expected)"
if ( build_url "/" "/v1/users" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected slash-only base_url)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Whitespace-only endpoint (Failure case expected)"
if ( build_url "https://api.example.com" "   " > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected whitespace-only endpoint)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Whitespace inside endpoint (Failure case expected)"
if ( build_url "https://api.example.com" "/v1/my users" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected whitespace in endpoint)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition: Tab/newline whitespace in arguments (Failure case expected)"
if ( build_url "https://api.example.com" $'/v1/users\tprofile' > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected tab character in endpoint)"
else
    test_pass "Failure caught successfully."
fi

echo "------------------------------------------------"
echo "All tests completed."