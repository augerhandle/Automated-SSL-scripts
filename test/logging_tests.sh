#!/usr/bin/env bash

# ========================================================================
# Test script for logging.sh
# ========================================================================

# ------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------

# Resolve paths relative to this test script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Source logging library and co-located test helpers
source "${LIB_DIR}/logging.sh"
source "${TEST_DIR}/test_helpers.sh"

# ------------------------------------------------------------------------
# test cases
# ------------------------------------------------------------------------

echo "Running logging.sh tests..."
echo "------------------------------------------------"

# 1. Test log_info
echo "[TEST] log_info format and output"
OUTPUT=$(log_info "Test info message" 2>&1)
echo "Got: $OUTPUT"
if echo "$OUTPUT" | grep -q '\[INFO \].*Test info message'; then
    test_pass "Success"
else
    test_fail "Failed"
fi

# 2. Test log_err
echo "[TEST] log_err format and output"
OUTPUT=$(log_err "Test error message" 2>&1)
echo "Got: $OUTPUT"
if echo "$OUTPUT" | grep -q '\[ERROR\].*Test error message'; then
    test_pass "Success"
else
    test_fail "Failed"
fi

# 3. Test log_verbose (disabled by default)
echo "[TEST] log_verbose (disabled when VERBOSE is unset)"
# Ensure we run this in a subshell without verbose variables set
OUTPUT=$(VERBOSE=0 DEBUG=0 log_verbose "Should not print" 2>&1)
if [[ -z "$OUTPUT" ]]; then
    test_pass "Success"
else
    echo "Got: $OUTPUT"
    test_fail "Failed (Output was not empty)"
fi

# 4. Test log_verbose (enabled via environment variable)
echo "[TEST] log_verbose (enabled via VERBOSE=1)"
OUTPUT=$(VERBOSE=1 log_verbose "Test debug message" 2>&1)
echo "Got: $OUTPUT"
if echo "$OUTPUT" | grep -q '\[DEBUG\].*Test debug message'; then
    test_pass "Success"
else
    test_fail "Failed"
fi

# 5. Test log_verbose_vars
echo "[TEST] log_verbose_vars (evaluates variable contents)"
TEST_VAR="hello_world"
OUTPUT=$(VERBOSE=1 log_verbose_vars TEST_VAR 2>&1)
echo "Got: $OUTPUT"
if echo "$OUTPUT" | grep -q '\[DEBUG\].*TEST_VAR=hello_world'; then
    test_pass "Success"
else
    test_fail "Failed"
fi

# 6. Test log_verbose_secret_vars
echo "[TEST] log_verbose_secret_vars (masks variable contents)"
SECRET_VAR="super_secret_password"
OUTPUT=$(VERBOSE=1 log_verbose_secret_vars SECRET_VAR 2>&1)
echo "Got: $OUTPUT"
if echo "$OUTPUT" | grep -q '\[DEBUG\].*SECRET_VAR=\*\*\*\*\*'; then
    # Double check that the actual secret did not leak into the output
    if echo "$OUTPUT" | grep -q "super_secret_password"; then
         test_fail "Failed (Secret leaked into output!)"
    else
         test_pass "Success"
    fi
else
    test_fail "Failed (Output format incorrect)"
fi

# 7. Test log_fatal
echo "[TEST] log_fatal (prints and exits with 1)"
# Must run in a subshell so it doesn't kill the test script itself
OUTPUT=$( (log_fatal "Test fatal message") 2>&1 )
EXIT_CODE=$?
echo "Got: $OUTPUT"
if [[ $EXIT_CODE -eq 1 ]] && echo "$OUTPUT" | grep -q '\[FATAL\].*Test fatal message'; then
    test_pass "Success"
else
    test_fail "Failed (Exit code: $EXIT_CODE)"
fi

echo "------------------------------------------------"
echo "All logging tests completed."