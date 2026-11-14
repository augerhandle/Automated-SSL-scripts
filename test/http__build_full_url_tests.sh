#!/usr/bin/env bash

# ========================================================================
# Test script for build_full_url in http.sh
# ========================================================================

# ------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------

# Resolve paths relative to this test script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

source "${LIB_DIR}/assert.sh"
source "${LIB_DIR}/http.sh"

# ------------------------------------------------------------------------
# setup
# ------------------------------------------------------------------------

# ANSI Color Codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color (Reset)

# ------------------------------------------------------------------------
# test cases
# ------------------------------------------------------------------------

echo "Running build_full_url tests..."
echo "------------------------------------------------"

# Helper function to evaluate expected results
evaluate_test() {
    local expected="$1"
    local actual="$2"
    
    if [[ "$expected" == "$actual" ]]; then
        printf "${GREEN} -> Success (Got: %s)${NC}\n\n" "$actual"
    else
        printf "${RED} -> Unexpected Failure (Expected: %s, Got: %s)${NC}\n\n" "$expected" "$actual"
    fi
}

# 1. Happy Cases: Standard formatting
echo "[TEST] Happy Case: No extra slashes"
RESULT=$(build_full_url "https://api.example.com" "v1/users")
evaluate_test "https://api.example.com/v1/users" "$RESULT"

echo "[TEST] Happy Case: Trailing slash on base URL only"
RESULT=$(build_full_url "https://api.example.com/" "v1/users")
evaluate_test "https://api.example.com/v1/users" "$RESULT"

echo "[TEST] Happy Case: Leading slash on endpoint only"
RESULT=$(build_full_url "https://api.example.com" "/v1/users")
evaluate_test "https://api.example.com/v1/users" "$RESULT"

echo "[TEST] Happy Case: Slashes on both base URL and endpoint"
RESULT=$(build_full_url "https://api.example.com/" "/v1/users")
evaluate_test "https://api.example.com/v1/users" "$RESULT"

# 2. Corner Conditions
echo "[TEST] Corner Condition: Empty endpoint"
RESULT=$(build_full_url "https://api.example.com" "")
evaluate_test "https://api.example.com/" "$RESULT"

echo "[TEST] Corner Condition: Sub-paths with multiple slashes in endpoint"
RESULT=$(build_full_url "https://api.example.com/" "/v1/users/profile/details/")
evaluate_test "https://api.example.com/v1/users/profile/details/" "$RESULT"

# 3. Argument Assertions (Expected Failures)
echo "[TEST] Corner Condition: Missing arguments (Failure case expected)"
# Run in subshell to prevent assert_argc from exiting the test script
if ( build_full_url "https://api.example.com" > /dev/null 2>&1 ); then
    printf "${RED} -> Unexpected Success (Test Failed: Should have rejected 1 argument)${NC}\n\n"
else
    printf "${GREEN} -> Failure caught successfully.${NC}\n\n"
fi

echo "[TEST] Corner Condition: Too many arguments (Failure case expected)"
if ( build_full_url "https://api.example.com" "/v1/users" "extra_arg" > /dev/null 2>&1 ); then
    printf "${RED} -> Unexpected Success (Test Failed: Should have rejected 3 arguments)${NC}\n\n"
else
    printf "${GREEN} -> Failure caught successfully.${NC}\n\n"
fi

echo "------------------------------------------------"
echo "All tests completed."