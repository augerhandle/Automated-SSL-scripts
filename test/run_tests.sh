#!/usr/bin/env bash

# ========================================================================
# Master Test Runner
# Discovers and runs all *_tests.sh suites in <project-root>/test
#
# Usage:
#   ./test/run_all_tests.sh                  # Run all test suites
#   ./test/run_all_tests.sh --offline        # Skip live network/echo test suites
#   ./test/run_all_tests.sh <suite_name.sh>  # Run a single test suite
# ========================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}"

source "${TEST_DIR}/test_helpers.sh"

OFFLINE_MODE=0
TARGET_SUITE=""

for arg in "$@"; do
    case "$arg" in
        --offline)
            OFFLINE_MODE=1
            ;;
        *)
            TARGET_SUITE="$arg"
            ;;
    esac
done

TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
SKIPPED_SUITES=0
FAILED_NAMES=()

run_test_suite() {
    local suite_path="$1"
    local suite_name
    suite_name="$(basename "$suite_path")"

    # Prevent infinite recursion if runner filename matches *_tests.sh
    if [[ "$suite_name" == "$(basename "${BASH_SOURCE[0]}")" ]]; then
        return 0
    fi

    if [[ ! -f "$suite_path" ]]; then
        printf "${RED}[ERROR] Test suite not found: %s${NC}\n\n" "$suite_name"
        ((FAILED_SUITES++))
        FAILED_NAMES+=("$suite_name")
        return 1
    fi

    # Skip live network suites when --offline is passed
    if [[ $OFFLINE_MODE -eq 1 && "$suite_name" == *"_echo_tests.sh" ]]; then
        printf "${YELLOW}[SKIP] %s (offline mode)${NC}\n\n" "$suite_name"
        ((SKIPPED_SUITES++))
        return 0
    fi

    ((TOTAL_SUITES++))
    printf "${YELLOW}=== Suite: %s ===${NC}\n" "$suite_name"

    local tmp_out
    tmp_out="$(mktemp)"

    bash "$suite_path" 2>&1 | tee "$tmp_out"
    local suite_exit=${PIPESTATUS[0]}

    # Detect failure if the suite exited non-zero OR emitted test_fail (ANSI red)
    if [[ $suite_exit -ne 0 ]] || grep -q $'\033\\[0;31m' "$tmp_out"; then
        ((FAILED_SUITES++))
        FAILED_NAMES+=("$suite_name")
    else
        ((PASSED_SUITES++))
    fi

    rm -f "$tmp_out"
    echo ""
}

echo "================================================"
echo "Running Test Suites in: ${TEST_DIR}"
if [[ $OFFLINE_MODE -eq 1 ]]; then
    echo "Mode: OFFLINE (skipping live echo/integration tests)"
fi
echo "================================================"
echo ""

if [[ -n "$TARGET_SUITE" ]]; then
    run_test_suite "${TEST_DIR}/${TARGET_SUITE}"
else
    for suite in "${TEST_DIR}"/*_tests.sh; do
        [[ -f "$suite" ]] || continue
        run_test_suite "$suite"
    done
fi

echo "================================================"
echo "Test Run Summary"
echo "------------------------------------------------"
echo "Total Executed : ${TOTAL_SUITES}"
printf "${GREEN}Passed         : ${PASSED_SUITES}${NC}\n"
if [[ $FAILED_SUITES -gt 0 ]]; then
    printf "${RED}Failed         : ${FAILED_SUITES}${NC}\n"
    for name in "${FAILED_NAMES[@]}"; do
        printf "${RED}  - %s${NC}\n" "$name"
    done
else
    echo "Failed         : 0"
fi
if [[ $SKIPPED_SUITES -gt 0 ]]; then
    printf "${YELLOW}Skipped        : ${SKIPPED_SUITES}${NC}\n"
fi
echo "================================================"

[[ $FAILED_SUITES -eq 0 ]]