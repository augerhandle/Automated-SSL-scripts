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
test_header "assert_true (Success case)"
assert_true "1 must equal 1" test 1 -eq 1
test_pass "Success"

test_header "assert_true (Failure case expected)"
if ( assert_true "1 must equal 2" test 1 -eq 2 ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 2. Test assert_argc
test_header "assert_argc (Success case)"
assert_argc 3 3
test_pass "Success"

test_header "assert_argc (Failure case expected)"
if ( assert_argc 2 5 ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 3. Test assert_min_argc
test_header "assert_min_argc (Success case - exact minimum)"
assert_min_argc 3 3
test_pass "Success"

test_header "assert_min_argc (Success case - above minimum)"
assert_min_argc 3 5
test_pass "Success"

test_header "assert_min_argc (Failure case expected - below minimum)"
if ( assert_min_argc 3 2 ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 4. Test assert_nonempty
test_header "assert_nonempty (Success case)"
TEST_STRING="hello world"
assert_nonempty TEST_STRING
test_pass "Success"

test_header "assert_nonempty (Failure case expected)"
EMPTY_STRING=""
if ( assert_nonempty EMPTY_STRING ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 5. Test assert_file_readable
test_header "assert_file_readable (Success case)"
TEST_FILE=$(mktemp)
assert_file_readable TEST_FILE
rm -f "$TEST_FILE" # cleanup
test_pass "Success"

test_header "assert_file_readable (Failure case expected - missing file)"
MISSING_FILE="/tmp/does_not_exist_$(date +%s)"
if ( assert_file_readable MISSING_FILE ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 6. Test assert_cmds
test_header "assert_cmds (Success case)"
assert_cmds cat echo ls
test_pass "Success"

test_header "assert_cmds (Failure case expected)"
if ( assert_cmds some_made_up_command ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 7. Test assert_regex
test_header "assert_regex (Success case - numeric port)"
assert_regex "Port must be numeric" "2083" '^[0-9]+$'
test_pass "Success"

test_header "assert_regex (Success case - valid UAPI module identifier)"
assert_regex "Module must be alphanumeric/underscore" "DomainInfo_1" '^[A-Za-z0-9_]+$'
test_pass "Success"

test_header "assert_regex (Failure case expected - non-matching value)"
if ( assert_regex "Port must be numeric" "2083abc" '^[0-9]+$' ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

test_header "assert_regex (Failure case expected - empty value against non-empty pattern)"
if ( assert_regex "Value must be numeric" "" '^[0-9]+$' ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

test_header "assert_regex (Failure case expected - missing arguments)"
if ( assert_regex "Only two args" "value" ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

# 8. Test assert_not_regex
test_header "assert_not_regex (Success case - no whitespace in hostname)"
assert_not_regex "Host must not contain whitespace" "cpanel.example.com" '[[:space:]]'
test_pass "Success"

test_header "assert_not_regex (Success case - empty string does not match disallowed pattern)"
assert_not_regex "Empty string has no whitespace" "" '[[:space:]]'
test_pass "Success"

test_header "assert_not_regex (Failure case expected - space in value)"
if ( assert_not_regex "Host must not contain whitespace" "cpanel.example .com" '[[:space:]]' ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

test_header "assert_not_regex (Failure case expected - tab/newline whitespace in value)"
if ( assert_not_regex "Value must not contain whitespace" $'bad\tvalue' '[[:space:]]' ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

test_header "assert_not_regex (Failure case expected - colon in username)"
if ( assert_not_regex "User must not contain whitespace or ':'" "user:name" '[[:space:]:]' ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

test_header "assert_not_regex (Failure case expected - missing arguments)"
if ( assert_not_regex "Only two args" "value" ); then
    test_fail "Unexpected Success (Test Failed)"
else
    test_pass "Failure caught successfully."
fi

echo "------------------------------------------------"
echo "All tests completed."