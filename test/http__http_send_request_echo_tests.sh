#!/usr/bin/env bash

# ========================================================================
# Live integration test script for send_http_request in http.sh
# (Tests real end-to-end HTTP requests against https://postman-echo.com)
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

BASE_HOST="postman-echo.com"
BASE_URL="https://${BASE_HOST}"

# ------------------------------------------------------------------------
# 1. Reachability Guard (Pre-Flight Check)
# ------------------------------------------------------------------------
echo "Checking reachability of ${BASE_URL}..."
if ! curl --silent --fail --head --max-time 10 "${BASE_URL}/get" > /dev/null 2>&1; then
    echo "[SKIP] ${BASE_URL} is unreachable or offline. Skipping live integration tests."
    exit 0
fi

echo "Running http.sh (send_http_request live integration) tests..."
echo "------------------------------------------------"

# ------------------------------------------------------------------------
# 2. Basic Connectivity & URL Normalization (build_url + GET)
# ------------------------------------------------------------------------
echo "[TEST] Happy Case (GET): Implicit https:// scheme and endpoint normalization"
RESPONSE=$(send_http_request "GET" "${BASE_HOST}" "/get")
EXIT_CODE=$?
assert_test_equals "0" "$EXIT_CODE"
if [[ "$RESPONSE" == *"\"url\":\"${BASE_URL}/get\""* ]] || [[ "$RESPONSE" == *"\"url\": \"${BASE_URL}/get\""* ]]; then
    test_pass "Normalized URL echoed back accurately."
else
    test_fail "Expected echoed URL '${BASE_URL}/get' in response: $RESPONSE"
fi

# ------------------------------------------------------------------------
# 3. Default & Custom Headers (build_curl_headers)
# ------------------------------------------------------------------------
echo "[TEST] Happy Case (Headers): Default Accept and User-Agent headers are sent"
RESPONSE=$(send_http_request "GET" "${BASE_URL}" "/get")
EXIT_CODE=$?
assert_test_equals "0" "$EXIT_CODE"
if [[ "$RESPONSE" == *"\"accept\":\"application/json\""* || "$RESPONSE" == *"\"accept\": \"application/json\""* ]] && \
   [[ "$RESPONSE" == *"\"user-agent\":\"Bash-API-Client/1.0\""* || "$RESPONSE" == *"\"user-agent\": \"Bash-API-Client/1.0\""* ]]; then
    test_pass "Default Accept and User-Agent headers verified."
else
    test_fail "Missing expected default headers in response: $RESPONSE"
fi

echo "[TEST] Happy Case (Headers): Multiline custom headers with spaces and colons"
CUSTOM_HEADERS=$'Authorization: cpanel user:token123\n\nX-Custom-Header: hello world'
RESPONSE=$(send_http_request "GET" "${BASE_URL}" "/get" "$CUSTOM_HEADERS")
EXIT_CODE=$?
assert_test_equals "0" "$EXIT_CODE"
if [[ "$RESPONSE" == *"\"authorization\":\"cpanel user:token123\""* || "$RESPONSE" == *"\"authorization\": \"cpanel user:token123\""* ]] && \
   [[ "$RESPONSE" == *"\"x-custom-header\":\"hello world\""* || "$RESPONSE" == *"\"x-custom-header\": \"hello world\""* ]]; then
    test_pass "Multiline custom headers preserved and blank lines ignored."
else
    test_fail "Missing expected custom headers in response: $RESPONSE"
fi

# ------------------------------------------------------------------------
# 4. URL-Encoded Parameters (build_curl_params on GET and POST)
# ------------------------------------------------------------------------
echo "[TEST] Happy Case (GET params): Query parameters with spaces, '&', '+', and empty values"
RESPONSE=$(send_http_request "GET" "${BASE_URL}" "/get" "" "greeting=hello world" "expr=a&b=c+d" "empty_val=")
EXIT_CODE=$?
assert_test_equals "0" "$EXIT_CODE"
if [[ "$RESPONSE" == *"\"greeting\":\"hello world\""* || "$RESPONSE" == *"\"greeting\": \"hello world\""* ]] && \
   [[ "$RESPONSE" == *"\"expr\":\"a&b=c+d\""* || "$RESPONSE" == *"\"expr\": \"a&b=c+d\""* ]] && \
   [[ "$RESPONSE" == *"\"empty_val\":\"\""* || "$RESPONSE" == *"\"empty_val\": \"\""* ]]; then
    test_pass "GET URL-encoded query parameters echoed back accurately."
else
    test_fail "GET query parameters did not match expected decoded values: $RESPONSE"
fi

echo "[TEST] Happy Case (POST params): Form-encoded parameters with special characters"
RESPONSE=$(send_http_request "POST" "${BASE_URL}" "/post" "" "domain=example.com" "note=line1 & line2 = ok")
EXIT_CODE=$?
assert_test_equals "0" "$EXIT_CODE"
if [[ "$RESPONSE" == *"\"domain\":\"example.com\""* || "$RESPONSE" == *"\"domain\": \"example.com\""* ]] && \
   [[ "$RESPONSE" == *"\"note\":\"line1 & line2 = ok\""* || "$RESPONSE" == *"\"note\": \"line1 & line2 = ok\""* ]]; then
    test_pass "POST URL-encoded form parameters echoed back accurately."
else
    test_fail "POST form parameters did not match expected decoded values: $RESPONSE"
fi

echo "[TEST] Happy Case (POST + Headers + Params): Combined custom header and form payload"
RESPONSE=$(send_http_request "POST" "${BASE_URL}" "/post" "X-Api-Key: secret:key" "user=alice" "role=admin")
EXIT_CODE=$?
assert_test_equals "0" "$EXIT_CODE"
if [[ "$RESPONSE" == *"\"x-api-key\":\"secret:key\""* || "$RESPONSE" == *"\"x-api-key\": \"secret:key\""* ]] && \
   [[ "$RESPONSE" == *"\"user\":\"alice\""* || "$RESPONSE" == *"\"user\": \"alice\""* ]] && \
   [[ "$RESPONSE" == *"\"role\":\"admin\""* || "$RESPONSE" == *"\"role\": \"admin\""* ]]; then
    test_pass "Combined POST headers and form payload verified."
else
    test_fail "Combined POST request failed verification: $RESPONSE"
fi

# ------------------------------------------------------------------------
# 5. HTTP Verb Routing (PUT, DELETE)
# ------------------------------------------------------------------------
echo "[TEST] Happy Case (PUT): HTTP PUT method routing with form data"
RESPONSE=$(send_http_request "PUT" "${BASE_URL}" "/put" "" "item=updated")
EXIT_CODE=$?
assert_test_equals "0" "$EXIT_CODE"
if [[ "$RESPONSE" == *"\"item\":\"updated\""* || "$RESPONSE" == *"\"item\": \"updated\""* ]]; then
    test_pass "PUT request routed and payload echoed."
else
    test_fail "PUT request failed verification: $RESPONSE"
fi

echo "[TEST] Happy Case (DELETE): HTTP DELETE method routing"
RESPONSE=$(send_http_request "DELETE" "${BASE_URL}" "/delete")
EXIT_CODE=$?
assert_test_equals "0" "$EXIT_CODE"
if [[ "$RESPONSE" == *"\"url\":\"${BASE_URL}/delete\""* || "$RESPONSE" == *"\"url\": \"${BASE_URL}/delete\""* ]]; then
    test_pass "DELETE request routed successfully."
else
    test_fail "DELETE request failed verification: $RESPONSE"
fi

# ------------------------------------------------------------------------
# 6. HTTP Error Status Handling (>= 400)
# ------------------------------------------------------------------------
echo "[TEST] Error Handling (401 Unauthorized): Returns non-zero exit code (Failure case expected)"
if ( send_http_request "GET" "${BASE_URL}" "/status/401" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have failed on HTTP 401)"
else
    test_pass "HTTP 401 failure caught successfully."
fi

echo "[TEST] Error Handling (404 Not Found): Returns non-zero exit code (Failure case expected)"
if ( send_http_request "GET" "${BASE_URL}" "/status/404" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have failed on HTTP 404)"
else
    test_pass "HTTP 404 failure caught successfully."
fi

echo "[TEST] Error Handling (500 Internal Server Error): Returns non-zero exit code (Failure case expected)"
if ( send_http_request "POST" "${BASE_URL}" "/status/500" "" "key=value" > /dev/null 2>&1 ); then
    test_fail "Unexpected Success (Test Failed: Should have failed on HTTP 500)"
else
    test_pass "HTTP 500 failure caught successfully."
fi

echo "------------------------------------------------"
echo "All tests completed."