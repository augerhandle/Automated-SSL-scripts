#!/usr/bin/env bash

# ========================================================================
# Pre-condition & validation test script for send_http_request in http.sh
# (All test cases fail before curl or the network is ever invoked)
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

echo "Running http.sh (send_http_request pre-condition/validation) tests..."
echo "------------------------------------------------"

echo "[TEST] Pre-condition (send_http_request): Zero arguments (Failure case expected)"
if ( send_http_request > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected 0 arguments)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition (send_http_request): Fewer than 3 required arguments (Failure case expected)"
if ( send_http_request "GET" "http://127.0.0.1:1" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected 2 arguments)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition (send_http_request): Empty HTTP_METHOD (Failure case expected)"
if ( send_http_request "" "http://127.0.0.1:1" "/test" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected empty HTTP_METHOD)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition (send_http_request): Empty BASE_URL (Failure case expected)"
if ( send_http_request "GET" "" "/test" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected empty BASE_URL)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition (send_http_request): Malformed BASE_URL rejected via build_url (Failure case expected)"
if ( send_http_request "GET" "http://" "/test" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected malformed BASE_URL)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition (send_http_request): Whitespace in ENDPOINT rejected via build_url (Failure case expected)"
if ( send_http_request "GET" "http://127.0.0.1:1" "/bad path" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected whitespace in ENDPOINT)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition (send_http_request): Malformed custom header rejected via build_curl_headers (Failure case expected)"
if ( send_http_request "GET" "http://127.0.0.1:1" "/test" "InvalidHeaderWithoutColon" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected malformed custom header)"
else
    test_pass "Failure caught successfully."
fi

echo "[TEST] Pre-condition (send_http_request): Malformed parameter rejected via build_curl_params (Failure case expected)"
if ( send_http_request "GET" "http://127.0.0.1:1" "/test" "" "invalid_param_without_equals" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have rejected malformed parameter)"
else
    test_pass "Failure caught successfully."
fi

echo "------------------------------------------------"
echo "All tests completed."