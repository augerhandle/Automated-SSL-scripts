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

# ========================================================================
# 1. Valid UAPI Success Responses
# ========================================================================

test_header "_cpanel_check_response (Success - standard UAPI envelope with 'status': 1)"
if ( _cpanel_check_response '{"status": 1, "errors": null, "messages": null, "data": ["ok"]}' ); then
    test_pass "Success"
else
    test_fail "Unexpected failure on valid status: 1 response"
fi

test_header "_cpanel_check_response (Success - compact JSON envelope without spaces)"
if ( _cpanel_check_response '{"data":{},"errors":null,"status":1}' ); then
    test_pass "Success"
else
    test_fail "Unexpected failure on compact status:1 response"
fi

test_header "_cpanel_check_response (Success - 'status': 1 at end of payload with array errors/messages)"
if ( _cpanel_check_response '{"errors":[],"messages":["Notice"],"data":null,"status": 1}' ); then
    test_pass "Success"
else
    test_fail "Unexpected failure when status: 1 is at end of string"
fi

test_header "_cpanel_check_response (Success - scalar/numeric 'data' payload)"
if ( _cpanel_check_response '{"status": 1, "errors": null, "data": 42}' ); then
    test_pass "Success"
else
    test_fail "Unexpected failure when 'data' is a scalar value"
fi

test_header "_cpanel_check_response (Success - nested 'status': 0 inside 'data' does not false-trigger)"
if ( _cpanel_check_response '{"status": 1, "errors": null, "data": [{"email": "user@example.com", "status": 0}]}' ); then
    test_pass "Success (root status: 1 respected despite nested status: 0)"
else
    test_fail "Unexpected failure on nested 'status': 0 inside 'data'"
fi

# ========================================================================
# 2. Precondition & Empty Body Checks
# ========================================================================

test_header "_cpanel_check_response (Failure expected - empty response body)"
if ( _cpanel_check_response "" 2>/dev/null ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Empty response body caught successfully."
fi

test_header "_cpanel_check_response (Failure expected - missing argument)"
if ( _cpanel_check_response 2>/dev/null ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Missing argument caught successfully."
fi

test_header "_cpanel_check_response (Failure expected - too many arguments)"
if ( _cpanel_check_response '{"status":1,"errors":null,"data":null}' "extra_arg" 2>/dev/null ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Extra argument caught successfully."
fi

# ========================================================================
# 3. JSON Syntax Validation (Step 1)
# ========================================================================

test_header "_cpanel_check_response (Failure expected - HTML reverse-proxy 502 error page)"
ERR_OUTPUT="$( _cpanel_check_response '<html><body><h1>502 Bad Gateway</h1></body></html>' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"non-JSON or malformed JSON"* ]]; then
    test_fail "Expected malformed JSON error message, got: $ERR_OUTPUT"
else
    test_pass "HTML 502 error page caught as non-JSON."
fi

test_header "_cpanel_check_response (Failure expected - truncated JSON stream)"
ERR_OUTPUT="$( _cpanel_check_response '{"status": 1, "errors": null, "data": [' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"non-JSON or malformed JSON"* ]]; then
    test_fail "Expected malformed JSON error message, got: $ERR_OUTPUT"
else
    test_pass "Truncated JSON stream caught successfully."
fi

# ========================================================================
# 4. UAPI Envelope Schema Contract Checks (Step 2)
# ========================================================================

test_header "_cpanel_check_response (Failure expected - schema violation: root JSON is array)"
ERR_OUTPUT="$( _cpanel_check_response '[{"status": 1, "errors": null, "data": []}]' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"root JSON value must be an object (got array)"* ]]; then
    test_fail "Expected root object schema message, got: $ERR_OUTPUT"
else
    test_pass "Non-object root JSON caught with specific schema message."
fi

test_header "_cpanel_check_response (Failure expected - schema violation: missing 'status' field)"
ERR_OUTPUT="$( _cpanel_check_response '{"result": "ok", "errors": null, "data": []}' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"missing or non-numeric 'status' field"* ]]; then
    test_fail "Expected missing 'status' schema message, got: $ERR_OUTPUT"
else
    test_pass "Missing 'status' field caught with specific schema message."
fi

test_header "_cpanel_check_response (Failure expected - schema violation: string 'status': \"1\")"
ERR_OUTPUT="$( _cpanel_check_response '{"status": "1", "errors": null, "data": []}' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"missing or non-numeric 'status' field"* ]]; then
    test_fail "Expected non-numeric 'status' schema message, got: $ERR_OUTPUT"
else
    test_pass "String 'status' field caught with specific schema message."
fi

test_header "_cpanel_check_response (Failure expected - schema violation: missing 'errors' field)"
ERR_OUTPUT="$( _cpanel_check_response '{"status": 1, "data": []}' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"missing required 'errors' field"* ]]; then
    test_fail "Expected missing 'errors' schema message, got: $ERR_OUTPUT"
else
    test_pass "Missing 'errors' field caught with specific schema message."
fi

test_header "_cpanel_check_response (Failure expected - schema violation: 'errors' is a string instead of null/array)"
ERR_OUTPUT="$( _cpanel_check_response '{"status": 1, "errors": "none", "data": []}' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"invalid 'errors' field type (expected null or array, got string)"* ]]; then
    test_fail "Expected invalid 'errors' type schema message, got: $ERR_OUTPUT"
else
    test_pass "Invalid 'errors' type caught with specific schema message."
fi

test_header "_cpanel_check_response (Failure expected - schema violation: missing 'data' field)"
ERR_OUTPUT="$( _cpanel_check_response '{"status": 1, "errors": null}' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"missing required 'data' field"* ]]; then
    test_fail "Expected missing 'data' schema message, got: $ERR_OUTPUT"
else
    test_pass "Missing 'data' field caught with specific schema message."
fi

test_header "_cpanel_check_response (Failure expected - schema violation: 'messages' is an object instead of null/array)"
ERR_OUTPUT="$( _cpanel_check_response '{"status": 1, "errors": null, "messages": {"info": "hi"}, "data": []}' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"invalid 'messages' field type (expected null or array, got object)"* ]]; then
    test_fail "Expected invalid 'messages' type schema message, got: $ERR_OUTPUT"
else
    test_pass "Invalid 'messages' type caught with specific schema message."
fi

# ========================================================================
# 5. Application-Level Errors & Unexpected Status Codes (Steps 3 & 4)
# ========================================================================

test_header "_cpanel_check_response (Failure expected - application error 'status': 0 with extracted error details)"
ERR_OUTPUT="$( _cpanel_check_response '{"status": 0, "errors": ["Access denied", "Invalid token"], "data": null}' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"Access denied; Invalid token"* ]]; then
    test_fail "Expected joined error details in stderr, got: $ERR_OUTPUT"
else
    test_pass "Application error (status: 0) caught and error details extracted."
fi

test_header "_cpanel_check_response (Failure expected - compact application error 'status':0 with null errors)"
ERR_OUTPUT="$( _cpanel_check_response '{"errors":null,"data":null,"status":0}' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"<no error details>"* ]]; then
    test_fail "Expected fallback '<no error details>' message, got: $ERR_OUTPUT"
else
    test_pass "Compact application error (status:0) with null errors handled cleanly."
fi

test_header "_cpanel_check_response (Failure expected - unexpected numeric 'status': 10)"
ERR_OUTPUT="$( _cpanel_check_response '{"status": 10, "errors": null, "data": []}' 2>&1 )"
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" != *"unexpected status value (expected .status == 1)"* ]]; then
    test_fail "Expected unexpected status value message, got: $ERR_OUTPUT"
else
    test_pass "Unexpected numeric 'status': 10 rejected cleanly."
fi

echo "------------------------------------------------"
echo "All _cpanel_check_response tests completed."