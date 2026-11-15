#!/usr/bin/env bash

# ========================================================================
# Test script for _cpanel_build_base_url in cpanel.sh
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

echo "Running _cpanel_build_base_url tests..."
echo "------------------------------------------------"

# 1. Default port 2083 on bare hostname
test_header "_cpanel_build_base_url (Bare hostname defaults to https://<host>:2083)"
RESULT="$(
    unset CPANEL_PORT
    CPANEL_HOST="cpanel.example.com"
    _cpanel_build_base_url
)"
if [[ "$RESULT" == "https://cpanel.example.com:2083" ]]; then
    test_pass "Got expected URL: $RESULT"
else
    test_fail "Expected 'https://cpanel.example.com:2083', got '$RESULT'"
fi

# 2. Custom CPANEL_PORT override
test_header "_cpanel_build_base_url (Custom CPANEL_PORT override)"
RESULT="$(
    CPANEL_HOST="cpanel.example.com"
    CPANEL_PORT="2087"
    _cpanel_build_base_url
)"
if [[ "$RESULT" == "https://cpanel.example.com:2087" ]]; then
    test_pass "Got expected URL: $RESULT"
else
    test_fail "Expected 'https://cpanel.example.com:2087', got '$RESULT'"
fi

# 3. Host already containing explicit port (should not double-append port)
test_header "_cpanel_build_base_url (Preserves explicit port in CPANEL_HOST)"
RESULT="$(
    unset CPANEL_PORT
    CPANEL_HOST="cpanel.example.com:9443"
    _cpanel_build_base_url
)"
if [[ "$RESULT" == "cpanel.example.com:9443" ]]; then
    test_pass "Got expected URL: $RESULT"
else
    test_fail "Expected 'cpanel.example.com:9443', got '$RESULT'"
fi

# 4. Host already containing https:// scheme (should not double-prepend scheme or port)
test_header "_cpanel_build_base_url (Preserves explicit https:// scheme in CPANEL_HOST)"
RESULT="$(
    unset CPANEL_PORT
    CPANEL_HOST="https://cpanel.example.com"
    _cpanel_build_base_url
)"
if [[ "$RESULT" == "https://cpanel.example.com" ]]; then
    test_pass "Got expected URL: $RESULT"
else
    test_fail "Expected 'https://cpanel.example.com', got '$RESULT'"
fi

# 5. Host already containing http:// scheme and port
test_header "_cpanel_build_base_url (Preserves explicit http:// scheme and port)"
RESULT="$(
    unset CPANEL_PORT
    CPANEL_HOST="http://localhost:8080"
    _cpanel_build_base_url
)"
if [[ "$RESULT" == "http://localhost:8080" ]]; then
    test_pass "Got expected URL: $RESULT"
else
    test_fail "Expected 'http://localhost:8080', got '$RESULT'"
fi

echo "------------------------------------------------"
echo "All _cpanel_build_base_url tests completed."