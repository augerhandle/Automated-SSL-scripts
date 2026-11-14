#!/usr/bin/env bash

# ========================================================================
# Transport-level failure test script for send_http_request in http.sh
# (Exercises real curl network/DNS failure paths without mocking curl)
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

echo "Running http.sh (send_http_request transport failure) tests..."
echo "------------------------------------------------"

echo "[TEST] Transport Failure (send_http_request): Connection refused on closed localhost port (http://127.0.0.1:1)"
if ( send_http_request "GET" "http://127.0.0.1:1" "/test" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have failed when connection is refused)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Transport Failure (send_http_request): POST with headers and params to closed localhost port (http://127.0.0.1:1)"
if ( send_http_request "POST" "http://127.0.0.1:1" "/test" "X-Test: value" "key=value" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have failed after full setup/serialization on refused connection)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Transport Failure (send_http_request): Unresolvable .invalid domain (DNS failure)"
if ( send_http_request "GET" "http://nonexistent.invalid" "/test" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have failed on unresolvable host)"
else
    test_pass "Failure caught successfully."
fi

echo "------------------------------------------------"
echo "All tests completed."