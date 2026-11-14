#!/usr/bin/env bash

# ========================================================================
# Test script for assert.sh
# ========================================================================

# ------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------

# Resolve paths relative to this test script's location
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
TEST_DIR="${SCRIPT_DIR}"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Source libraries and co-located test helpers
source "${LIB_DIR}/assert.sh"
source "${TEST_DIR}/test_helpers.sh"

# ------------------------------------------------------------------------
# test cases
# ------------------------------------------------------------------------

echo "Running assert.sh tests..."
echo "------------------------------------------------"

# 1. Test assert_true
echo "[TEST] assert_true (Success case)"
assert_true "1 must equal 1" test 1 -eq 1
test_pass "Success"

echo "[TEST] assert_true (Failure case expected)"
if ( assert_true "1 must equal 2" test 1 -eq 2 ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 2. Test assert_argc
echo "[TEST] assert_argc (Success case)"
assert_argc 3 3
test_pass "Success"

echo "[TEST] assert_argc (Failure case expected)"
if ( assert_argc 2 5 ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 3. Test assert_min_argc
echo "[TEST] assert_min_argc (Success case - exact minimum)"
assert_min_argc 3 3
test_pass "Success"

echo "[TEST] assert_min_argc (Success case - above minimum)"
assert_min_argc 3 5
test_pass "Success"

echo "[TEST] assert_min_argc (Failure case expected - below minimum)"
if ( assert_min_argc 3 2 ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 4. Test assert_nonempty
echo "[TEST] assert_nonempty (Success case)"
TEST_STRING="hello world"
assert_nonempty TEST_STRING
test_pass "Success"

echo "[TEST] assert_nonempty (Failure case expected)"
EMPTY_STRING=""
if ( assert_nonempty EMPTY_STRING ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 5. Test assert_file_readable
echo "[TEST] assert_file_readable (Success case)"
TEST_FILE=$(mktemp)
assert_file_readable TEST_FILE
rm -f "$TEST_FILE" # cleanup
test_pass "Success"

echo "[TEST] assert_file_readable (Failure case expected - missing file)"
MISSING_FILE="/tmp/does_not_exist_$(date +%s)"
if ( assert_file_readable MISSING_FILE ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 6. Test assert_cmds
echo "[TEST] assert_cmds (Success case)"
assert_cmds cat echo ls
test_pass "Success"

echo "[TEST] assert_cmds (Failure case expected)"
if ( assert_cmds some_made_up_command ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

echo "------------------------------------------------"
echo "All tests completed."