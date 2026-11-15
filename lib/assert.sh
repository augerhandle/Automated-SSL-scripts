#!/usr/bin/env bash

# ========================================================================
# assertion functions
# ========================================================================

# prevent sourcing multiple times
[ -n "${_DAH_ASSERT_SH:-}" ] && return 0


# ========================================================================
# dependencies
# ========================================================================
# Resolve directory relative to THIS library file
_DAH_ASSERT_SH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DAH_ASSERT_SH_LIB_DIR="${_DAH_ASSERT_SH_SCRIPT_DIR}"

# Source dependencies
source "${_DAH_ASSERT_SH_LIB_DIR}/logging.sh"

# ========================================================================
# Internal functions
# ========================================================================

# Core assertion failure reporter with call-stack inspection
# Uses BASH_SOURCE[2] / BASH_LINENO[1] / FUNCNAME[1..2] to point at the caller
_assert_fail() {
    local msg="$1"
    local assert_func="${FUNCNAME[1]:-main}"
    local caller_func="${FUNCNAME[2]:-main}"
    local caller_file="${BASH_SOURCE[2]:-${BASH_SOURCE[1]:-$0}}"
    local caller_line="${BASH_LINENO[1]:-0}"

    log_fatal "ASSERTION FAILED (${assert_func}()) in ${caller_func}() at ${caller_file##*/}:${caller_line}: ${msg}"
}

# ========================================================================
# Exported functions
# ========================================================================

# Assert a condition expression (evaluates via [[ ... ]] or command exit status)
# Usage: assert_true "count must be positive" test "$count" -gt 0
assert_true() {
    if (( $# < 2 )); then
        _assert_fail "requires a failure message and a command"
    fi
    local msg="$1"
    shift
    if ! "$@"; then
        _assert_fail "$msg"
    fi
}

# Assert exact argument count
# Usage: assert_argc 3 "$#"
assert_argc() {
    if (( $# != 2 )); then
        _assert_fail "requires expected and actual argument counts"
    fi
    local expected="$1"
    local actual="$2"
    if (( actual != expected )); then
        _assert_fail "expected ${expected} arguments, got ${actual}"
    fi
}

# Assert minimum argument count
# Usage: assert_min_argc 3 "$#"
assert_min_argc() {
    if (( $# != 2 )); then
        _assert_fail "requires minimum expected and actual argument counts"
    fi
    local min_expected="$1"
    local actual="$2"
    if (( actual < min_expected )); then
        _assert_fail "expected at least ${min_expected} arguments, got ${actual}"
    fi
}

# Assert one or more variables are set and non-empty (by variable name)
# Usage: assert_nonempty zone region cluster_name
assert_nonempty() {
    if (( $# == 0 )); then
        _assert_fail "requires at least one variable name"
    fi

    local _assert_var_name
    for _assert_var_name in "$@"; do
        # Guard against empty strings or invalid variable identifiers being passed
        if [[ ! "$_assert_var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            _assert_fail "invalid variable name '${_assert_var_name}'"
        fi

        # Guard against nameref collisions with internal _assert_* local variables
        if [[ "$_assert_var_name" == _assert_* ]]; then
            _assert_fail "reserved prefix _assert_ not allowed in variable names. The variable '${_assert_var_name}' violates this."
        fi

        local _assert_val
        eval "_assert_val=\${$_assert_var_name-}"
        if [[ -z "$_assert_val" ]]; then
            _assert_fail "variable '${_assert_var_name}' must not be empty"
        fi
    done
}

# Assert one or more file paths stored in variables exist and are readable
# Usage: assert_file_readable cert_file key_file ca_file
assert_file_readable() {
    if (( $# == 0 )); then
        _assert_fail "requires at least one variable name"
    fi

    local _assert_var_name
    for _assert_var_name in "$@"; do
        if [[ ! "$_assert_var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            _assert_fail "invalid variable name '${_assert_var_name}'"
        fi

        if [[ "$_assert_var_name" == _assert_* ]]; then
            _assert_fail "reserved prefix _assert_ not allowed in variable names. The variable '${_assert_var_name}' violates this."
        fi

        local _assert_path
        eval "_assert_path=\${$_assert_var_name-}"

        if [[ -z "$_assert_path" ]]; then
            _assert_fail "variable '${_assert_var_name}' must not be empty"
        fi

        if [[ ! -e "$_assert_path" ]]; then
            _assert_fail "file '${_assert_var_name}' (${_assert_path}) does not exist"
        fi

        if [[ ! -f "$_assert_path" ]]; then
            _assert_fail "path '${_assert_var_name}' (${_assert_path}) is not a regular file"
        fi

        if [[ ! -r "$_assert_path" ]]; then
            _assert_fail "file '${_assert_var_name}' (${_assert_path}) is not readable (permission denied)"
        fi
    done
}

# Assert required external binaries exist before running
# Usage: assert_cmds curl jq mktemp
assert_cmds() {
    if (( $# == 0 )); then 
        _assert_fail "requires at least one command name"; 
    fi

    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            _assert_fail "required command '${cmd}' not found in PATH"
        fi
    done
}

# Asserts that a string matches a Bash extended regular expression.
# Usage: assert_regex "Error message" "$value" '^[0-9]+$'
assert_regex() {
    assert_argc 3 $#
    local msg="$1"
    local value="$2"
    local pattern="$3"

    if ! [[ "$value" =~ $pattern ]]; then
        log_fatal "Assertion failed: ${msg} (got: '${value}', expected pattern: '${pattern}')"
    fi
}

# Asserts that a string does NOT match a Bash extended regular expression.
# Usage: assert_not_regex "Error message" "$value" '[[:space:]]'
assert_not_regex() {
    assert_argc 3 $#
    local msg="$1"
    local value="$2"
    local pattern="$3"

    if [[ "$value" =~ $pattern ]]; then
        log_fatal "Assertion failed: ${msg} (got: '${value}', disallowed pattern: '${pattern}')"
    fi
}

# Set guard only after everything in the file loaded cleanly
_DAH_ASSERT_SH=1
