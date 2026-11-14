#!/usr/bin/env bash

# ========================================================================
# Logging functions
# ========================================================================

# prevent sourcing multiple times
[[ -n "${_DAH_LOGGING_SH_LOADED:-}" ]] && return 0

# ========================================================================
# internal functions
# ========================================================================

_log_caller() {
    local self="${BASH_SOURCE[0]}"
    local i=1

    # Walk up the call stack until we exit this file (logging.sh).
    # Most public log_* functions are 1 frame above _log_caller (index 2),
    # but multi-hop helpers like log_verbose_vars() call log_verbose()
    # internally (index 3+). Skipping frames defined in logging.sh ensures
    # we always report the external caller rather than logging.sh itself.
    while [[ "${BASH_SOURCE[$i]:-}" == "$self" ]]; do
        ((i++))
    done

    local script="$(basename -- "${BASH_SOURCE[$i]:-$0}")"
    local func="${FUNCNAME[$i]:-main}"
    local line="${BASH_LINENO[$((i - 1))]:-0}"

    echo "${script}:${func}():${line}"
}

_log_timestamp() {
    # macOS (BSD date) and Linux (GNU date) compatible ISO-8601 format
    date +'%Y-%m-%dT%H:%M:%S%z'
}

_is_verbose() {
    [[ -f "$HOME/.enable_verbose_logging" ]] && return 0
    local val="${VERBOSE:-${DEBUG:-false}}"
    case "${val}" in
        1|[tT][rR][uU][eE]|[yY][eE][sS]|[oO][nN]) return 0 ;;
        *) return 1 ;;
    esac
}

# ========================================================================
# Exported functions
# ========================================================================

log_info() {
    echo "$(_log_timestamp) [INFO ] [$(_log_caller)] $*" >&2
}

log_verbose() {
    if _is_verbose; then
        echo "$(_log_timestamp) [DEBUG] [$(_log_caller)] $*" >&2
    fi
}

log_verbose_vars() {
    local var val
    for var in "$@"; do
        if [[ ! "$var" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            log_verbose "<invalid var '${var}'>"
            continue
        fi
        
        # Safely evaluate and expand the variable, defaulting to empty if unset.
        # This completely bypasses the pre-4.3 "set -u" indirect expansion bug.
        eval "val=\${$var-}"
        log_verbose "$var=$val"
    done
    return 0
}

log_verbose_secret_vars() {
    local var
    for var in "$@"; do
        if [[ ! "$var" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            log_verbose "<invalid var '${var}'>"
            continue
        fi
        log_verbose "$var=*****"
    done
    return 0
}

log_err() {
    echo "$(_log_timestamp) [ERROR] [$(_log_caller)] $*" >&2
}

log_fatal() {
    echo "$(_log_timestamp) [FATAL] [$(_log_caller)] $*" >&2
    exit 1
}

# Set guard only after everything in the file loaded cleanly
_DAH_LOGGING_SH_LOADED=1
