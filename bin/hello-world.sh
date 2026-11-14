#!/usr/bin/env bash
set -Eeuo pipefail

# ========================================================================
# DESCRIPTION
# A silly script for use in testing
# ========================================================================

# ========================================================================
# SETUP 
# ========================================================================

# Resolve directory relative to library file
_THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${_THIS_DIR}/../lib"

# Source dependencies
source "${_LIB_DIR}/logging.sh"

# ========================================================================
# SCRIPT BODY
# ========================================================================

log_info "Hello, world!"