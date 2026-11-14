#!/usr/bin/env bash
set -euo pipefail

# ========================================================================
# SETUP 
# ========================================================================
# Resolve directory relative to THIS library file
_THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${_THIS_DIR}"

# Source dependencies
source "${_LIB_DIR}/logging.sh"
source "$${_LIB_DIR}/check-vars.sh"

# ========================================================================
# SCRIPT BODY
# ========================================================================

log_info "running echo hook..."

check_vars CERTBOT_IDENTIFIER CERTBOT_VALIDATION CERTBOT_REMAINING_CHALLENGES CERTBOT_ALL_IDENTIFIERS
log_env_vars CERTBOT_IDENTIFIER CERTBOT_VALIDATION CERTBOT_REMAINING_CHALLENGES CERTBOT_ALL_IDENTIFIERS
