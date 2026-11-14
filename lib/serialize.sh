#!/usr/bin/env bash

# ========================================================================
# Argument serialization and deserialization utilities (Bash 3.2+)
# ========================================================================

# prevent sourcing multiple times
[ -n "${_DAH_SERIALIZE_SH:-}" ] && return 0

# ========================================================================
# Dependencies
# ========================================================================
# Resolve directory relative to THIS library file
_DAH_SERIALIZE_SH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DAH_SERIALIZE_SH_LIB_DIR="${_DAH_SERIALIZE_SH_SCRIPT_DIR}"

# Source dependencies
source "${_DAH_SERIALIZE_SH_LIB_DIR}/logging.sh"
source "${_DAH_SERIALIZE_SH_LIB_DIR}/assert.sh"

# ========================================================================
# PUBLIC FUNCTIONS
# The functions exported by this module "serialize" and "deserialize" 
# data for passing between Bash functions via stdout/stdin.
#
# The data being passed are sequences of arguments. In this context, "argument" 
# (or "arg") is any arbitrary strings—with no required structure. They can be 
#    - empty strings (""), 
#    - single words ("GET"), 
#    - strings with spaces ("Accept: application/json"), 
#    - multiline text, or 
#    - strings full of quotes, $ signs, and special symbols, etc...
# The term "argument" comes from how Bash itself passes data around:
# ordered lists of arbitrary Bash strings (where each string is kept intact 
# as a single discrete item, regardless of spaces, newlines, or punctuation inside it).
#
# The idea is to serialize zero or more arbitrary strings into a single 
# shell-quoted string that can be safely passed via stdout or as a single 
# function argument. (Here, "shell-quoted" means that all characters possibly 
# interpretable by Bash, such as spaces, quotes, or '$'—have been escaped so 
# they are treated strictly as literal text when unpacked by deserialize_args.)
#
# The process of marshalling the individual arguments into a shell-quoted string
# is called "serialization". 
#
# The process of unmarshaling the arguments out 
# of the shell-quoted string back into an array is called "deserialization".
# ========================================================================

# ------------------------------------------------------------------------
# Serializes zero or more arguments into a single shell-quoted string.
# Useful for returning lists via stdout or passing an array as a single
# positional argument to another function.
#
# Arguments:
#   $@ - Zero or more strings to serialize
# Outputs:
#   Writes shell-quoted arguments to stdout (safe for deserialize_args).
# Example:
#   serialize_args "Authorization: cpanel user:token" "X-Custom: val"
#   # => Authorization:\ cpanel\ user:token X-Custom:\ val
# ------------------------------------------------------------------------
serialize_args() {
    log_verbose "Serializing $# argument(s)"

    # ---------------
    # IMPLEMENTATION
    # ---------------
    if [[ $# -eq 0 ]]; then
        log_verbose "No arguments provided; returning empty serialized string"
        return 0
    fi

    local serialized
    serialized=$(printf '%q ' "$@")
    log_verbose "serialized: $serialized"

    # ---------------
    # POST-CONDITIONS
    # ---------------
    assert_nonempty serialized

    printf '%s' "${serialized}"
}

# ------------------------------------------------------------------------
# Deserializes a shell-quoted string (produced by serialize_args or
# printf '%q ') into a named Bash array in the caller's scope.
#
# Arguments:
#   $1 - Name of the destination array variable (valid Bash identifier)
#   $2 - Shell-quoted string to deserialize (may be empty)
# Outputs:
#   Populates the named array in the caller's scope.
# Example:
#   local headers=()
#   deserialize_args headers "$packed_headers"
# ------------------------------------------------------------------------
deserialize_args() {
    assert_argc 2 $#
    local target_var="$1"
    local serialized="$2"

    log_verbose "deserializing into '${target_var}': $serialized"

    # ---------------
    # PRE-CONDITIONS
    # ---------------
    # Prevent variable-name injection: ensure $1 is a valid Bash identifier
    assert_true "target_var must be a valid Bash variable name" \
        bash -c '[[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]' _ "$target_var"

    # ---------------
    # IMPLEMENTATION
    # ---------------
    # Clear destination array first (handles empty or whitespace-only input safely)
    eval "${target_var}=()"

    if [[ -z "${serialized//[^[:space:]]/}" ]]; then
        log_verbose "serialized input is empty/whitespace-only; cleared '${target_var}' (0 elements)"
        return 0
    fi

    eval "${target_var}=(${serialized})"

    local element_count
    eval "element_count=\${#${target_var}[@]}"
    log_verbose "deserialized ${element_count} element(s) into '${target_var}'"
}

# Set guard only after everything in the file loaded cleanly
_DAH_SERIALIZE_SH=1