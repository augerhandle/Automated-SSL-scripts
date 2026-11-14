#!/usr/bin/env bash

# ========================================================================
# Shared test reporting helpers
# ========================================================================

# ANSI Color Codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color (Reset)

test_pass() {
    local msg="${1:-Success}"
    printf "${GREEN} -> %s${NC}\n\n" "$msg"
}

test_fail() {
    local msg="${1:-Failed}"
    printf "${RED} -> %s${NC}\n\n" "$msg"
}

assert_test_equals() {
    local expected="$1"
    local actual="$2"

    if [[ "$expected" == "$actual" ]]; then
        test_pass "Success (Got: $actual)"
    else
        test_fail "Unexpected Failure (Expected: $expected, Got: $actual)"
    fi
}