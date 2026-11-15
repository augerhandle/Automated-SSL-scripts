#!/usr/bin/env bash

# ========================================================================
# Test script for _cpanel_check_response in cpanel.sh
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
# Test Cases
# ------------------------------------------------------------------------

echo "Running _cpanel_check_response tests..."
echo "------------------------------------------------"

# 1. Valid success response ("status": 1 with spaces)
test_header "_cpanel_check_response (Success - standard JSON with 'status': 1)"
if ( _cpanel_check_response '{"status": 1, "errors": null, "data": ["ok"]}' ); then
    test_pass "Success"
else
    test_fail "Unexpected failure on valid status: 1 response"
fi

# 2. Valid compact success response ("status":1 without spaces)
test_header "_cpanel_check_response (Success - compact JSON with 'status':1)"
if ( _cpanel_check_response '{"data":{},"status":1}' ); then
    test_pass "Success"
else
    test_fail "Unexpected failure on compact status:1 response"
fi

# 3. Valid response where "status": 1 is at the very end of string
test_header "_cpanel_check_response (Success - 'status': 1 at end of payload)"
if ( _cpanel_check_response '{"errors":null,"status": 1}' ); then
    test_pass "Success"
else
    test_fail "Unexpected failure when status: 1 is at end of string"
fi

# 4. Application-level failure ("status": 0 with spaces)
test_header "_cpanel_check_response (Failure expected - application error 'status': 0)"
if ( _cpanel_check_response '{"status": 0, "errors": ["Access denied"], "data": null}' 2>/dev/null ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Application error (status: 0) caught successfully."
fi

# 5. Application-level failure ("status":0 without spaces)
test_header "_cpanel_check_response (Failure expected - compact application error 'status':0)"
if ( _cpanel_check_response '{"errors":["Invalid parameter"],"status":0}' 2>/dev/null ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Compact application error (status:0) caught successfully."
fi

# 6. Empty response body
test_header "_cpanel_check_response (Failure expected - empty response body)"
if ( _cpanel_check_response "" 2>/dev/null ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Empty response body caught successfully."
fi

# 7. Missing argument
test_header "_cpanel_check_response (Failure expected - missing argument)"
if ( _cpanel_check_response 2>/dev/null ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Missing argument caught successfully."
fi

# 8. Malformed / non-UAPI JSON missing status field
test_header "_cpanel_check_response (Failure expected - JSON missing 'status' field)"
if ( _cpanel_check_response '{"result": "ok", "data": []}' 2>/dev/null ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Missing 'status' field caught successfully."
fi

# 9. Boundary check: "status": 10 must not match "status": 1
test_header "_cpanel_check_response (Failure expected - boundary check 'status': 10)"
if ( _cpanel_check_response '{"status": 10, "data": []}' 2>/dev/null ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Boundary check rejected 'status': 10 successfully."
fi

# 10. Boundary check: "status": 01 must not match "status": 0 or 1
test_header "_cpanel_check_response (Failure expected - boundary check 'status': 01)"
if ( _cpanel_check_response '{"status": 01, "data": []}' 2>/dev/null ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Boundary check rejected 'status': 01 successfully."
fi

echo "------------------------------------------------"
echo "All _cpanel_check_response tests completed."