#!/usr/bin/env bash

# ========================================================================
# Test script for assert.sh
# ========================================================================

# ANSI Color Codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color (Reset)

# Resolve paths relative to this test script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Source the assert library
source "${LIB_DIR}/assert.sh"

echo "Running assert.sh tests..."
echo "------------------------------------------------"

# 1. Test assert_true
echo "[TEST] assert_true (Success case)"
assert_true "1 must equal 1" test 1 -eq 1
printf "${GREEN} -> Success${NC}\n\n"

echo "[TEST] assert_true (Failure case expected)"
if ( assert_true "1 must equal 2" test 1 -eq 2 ); then
    printf "${RED} -> Unexpected Success (Test Failed)${NC}\n\n"
else
    printf "${GREEN} -> Failure caught successfully.${NC}\n\n"
fi

# 2. Test assert_argc
echo "[TEST] assert_argc (Success case)"
assert_argc 3 3
printf "${GREEN} -> Success${NC}\n\n"

echo "[TEST] assert_argc (Failure case expected)"
if ( assert_argc 2 5 ); then
    printf "${RED} -> Unexpected Success (Test Failed)${NC}\n\n"
else
    printf "${GREEN} -> Failure caught successfully.${NC}\n\n"
fi

# 3. Test assert_min_argc
echo "[TEST] assert_min_argc (Success case - exact minimum)"
assert_min_argc 3 3
printf "${GREEN} -> Success${NC}\n\n"

echo "[TEST] assert_min_argc (Success case - above minimum)"
assert_min_argc 3 5
printf "${GREEN} -> Success${NC}\n\n"

echo "[TEST] assert_min_argc (Failure case expected - below minimum)"
if ( assert_min_argc 3 2 ); then
    printf "${RED} -> Unexpected Success (Test Failed)${NC}\n\n"
else
    printf "${GREEN} -> Failure caught successfully.${NC}\n\n"
fi

# 4. Test assert_nonempty
echo "[TEST] assert_nonempty (Success case)"
TEST_STRING="hello world"
assert_nonempty TEST_STRING
printf "${GREEN} -> Success${NC}\n\n"

echo "[TEST] assert_nonempty (Failure case expected)"
EMPTY_STRING=""
if ( assert_nonempty EMPTY_STRING ); then
    printf "${RED} -> Unexpected Success (Test Failed)${NC}\n\n"
else
    printf "${GREEN} -> Failure caught successfully.${NC}\n\n"
fi

# 5. Test assert_file_readable
echo "[TEST] assert_file_readable (Success case)"
TEST_FILE=$(mktemp)
assert_file_readable TEST_FILE
rm -f "$TEST_FILE" # cleanup
printf "${GREEN} -> Success${NC}\n\n"

echo "[TEST] assert_file_readable (Failure case expected - missing file)"
MISSING_FILE="/tmp/does_not_exist_$(date +%s)"
if ( assert_file_readable MISSING_FILE ); then
    printf "${RED} -> Unexpected Success (Test Failed)${NC}\n\n"
else
    printf "${GREEN} -> Failure caught successfully.${NC}\n\n"
fi

# 6. Test assert_cmds
echo "[TEST] assert_cmds (Success case)"
assert_cmds cat echo ls
printf "${GREEN} -> Success${NC}\n\n"

echo "[TEST] assert_cmds (Failure case expected)"
if ( assert_cmds some_made_up_command ); then
    printf "${RED} -> Unexpected Success (Test Failed)${NC}\n\n"
else
    printf "${GREEN} -> Failure caught successfully.${NC}\n\n"
fi

echo "------------------------------------------------"
echo "All tests completed."