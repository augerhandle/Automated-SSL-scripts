#!/usr/bin/env bash

# ========================================================================
# Test script for _cpanel_validate_env in cpanel.sh
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

echo "Running _cpanel_validate_env tests..."
echo "------------------------------------------------"

# 1. Valid configurations
test_header "_cpanel_validate_env (Success - standard hostname)"
if (
    CPANEL_HOST="cpanel.example.com"
    CPANEL_USER="testuser"
    CPANEL_TOKEN="ABCDEF1234567890"
    _cpanel_validate_env
); then
    test_pass "Success"
else
    test_fail "Unexpected failure on valid standard environment"
fi

test_header "_cpanel_validate_env (Success - host with https:// scheme and port)"
if (
    CPANEL_HOST="https://cpanel.example.com:2083"
    CPANEL_USER="testuser"
    CPANEL_TOKEN="ABCDEF1234567890"
    _cpanel_validate_env
); then
    test_pass "Success"
else
    test_fail "Unexpected failure on valid https:// host with port"
fi

test_header "_cpanel_validate_env (Success - host with http:// scheme and path)"
if (
    CPANEL_HOST="http://localhost:8080/cpsess12345"
    CPANEL_USER="testuser"
    CPANEL_TOKEN="ABCDEF1234567890"
    _cpanel_validate_env
); then
    test_pass "Success"
else
    test_fail "Unexpected failure on valid http:// host with path"
fi

# 2. Missing / empty required variables
test_header "_cpanel_validate_env (Failure expected - empty CPANEL_HOST)"
if (
    CPANEL_HOST=""
    CPANEL_USER="testuser"
    CPANEL_TOKEN="ABCDEF1234567890"
    _cpanel_validate_env
); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

test_header "_cpanel_validate_env (Failure expected - unset CPANEL_HOST)"
if (
    unset CPANEL_HOST
    CPANEL_USER="testuser"
    CPANEL_TOKEN="ABCDEF1234567890"
    _cpanel_validate_env
); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

test_header "_cpanel_validate_env (Failure expected - empty CPANEL_USER)"
if (
    CPANEL_HOST="cpanel.example.com"
    CPANEL_USER=""
    CPANEL_TOKEN="ABCDEF1234567890"
    _cpanel_validate_env
); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

test_header "_cpanel_validate_env (Failure expected - empty CPANEL_TOKEN)"
if (
    CPANEL_HOST="cpanel.example.com"
    CPANEL_USER="testuser"
    CPANEL_TOKEN=""
    _cpanel_validate_env
); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 3. Malformed CPANEL_HOST
test_header "_cpanel_validate_env (Failure expected - whitespace in CPANEL_HOST)"
if (
    CPANEL_HOST="cpanel.example .com"
    CPANEL_USER="testuser"
    CPANEL_TOKEN="ABCDEF1234567890"
    _cpanel_validate_env
); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

test_header "_cpanel_validate_env (Failure expected - invalid scheme in CPANEL_HOST)"
if (
    CPANEL_HOST="ftp://cpanel.example.com"
    CPANEL_USER="testuser"
    CPANEL_TOKEN="ABCDEF1234567890"
    _cpanel_validate_env
); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

test_header "_cpanel_validate_env (Failure expected - scheme-only CPANEL_HOST)"
if (
    CPANEL_HOST="https://"
    CPANEL_USER="testuser"
    CPANEL_TOKEN="ABCDEF1234567890"
    _cpanel_validate_env
); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 4. Malformed CPANEL_USER
test_header "_cpanel_validate_env (Failure expected - whitespace in CPANEL_USER)"
if (
    CPANEL_HOST="cpanel.example.com"
    CPANEL_USER="test user"
    CPANEL_TOKEN="ABCDEF1234567890"
    _cpanel_validate_env
); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

test_header "_cpanel_validate_env (Failure expected - colon in CPANEL_USER)"
if (
    CPANEL_HOST="cpanel.example.com"
    CPANEL_USER="test:user"
    CPANEL_TOKEN="ABCDEF1234567890"
    _cpanel_validate_env
); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 5. Malformed CPANEL_TOKEN & secret leakage verification
test_header "_cpanel_validate_env (Failure expected - whitespace in CPANEL_TOKEN without leaking secret)"
SECRET_CANARY="TOPSECRET_TOKEN_999"
ERR_OUTPUT="$(
    CPANEL_HOST="cpanel.example.com"
    CPANEL_USER="testuser"
    CPANEL_TOKEN="${SECRET_CANARY} with_space"
    _cpanel_validate_env 2>&1
)"
STATUS=$?

if [[ $STATUS -eq 0 ]]; then
    test_fail "Unexpected Success (Test Failed)"
elif [[ "$ERR_OUTPUT" == *"$SECRET_CANARY"* ]]; then
    test_fail "Security failure: malformed CPANEL_TOKEN leaked into error output!"
else
    test_pass "Failure caught cleanly with secret redacted."
fi

echo "------------------------------------------------"
echo "All _cpanel_validate_env tests completed."