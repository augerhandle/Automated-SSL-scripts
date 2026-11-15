#!/usr/bin/env bash

# ========================================================================
# cPanel UAPI DomainInfo Module
# Dependencies: assert.sh, logging.sh, http.sh, cpanel.sh, jq
# ========================================================================

# prevent sourcing multiple times
[ -n "${_DAH_CPANEL_DOMAIN_INFO_SH:-}" ] && return 0

# ========================================================================
# dependencies
# ========================================================================
# Resolve directory relative to THIS library file
_DAH_CPANEL_DOMAIN_INFO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DAH_CPANEL_DOMAIN_INFO_LIB_DIR="${_DAH_CPANEL_DOMAIN_INFO_SCRIPT_DIR}"

# Source dependencies
source "${_DAH_CPANEL_DOMAIN_INFO_LIB_DIR}/logging.sh"
source "${_DAH_CPANEL_DOMAIN_INFO_LIB_DIR}/assert.sh"
source "${_DAH_CPANEL_DOMAIN_INFO_LIB_DIR}/http.sh"
source "${_DAH_CPANEL_DOMAIN_INFO_LIB_DIR}/cpanel.sh"

# ------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------

# Retrieves all domains associated with the authenticated cPanel account
# via UAPI GET DomainInfo/list_domains.
#
# Required Environment Variables (validated by send_cpanel_uapi_request):
#   CPANEL_HOST   Hostname or base URL (e.g., cpanel.example.com)
#   CPANEL_USER   cPanel account username
#   CPANEL_TOKEN  cPanel API token
# Optional Environment Variables:
#   CPANEL_PORT   Port number (default: 2083)
#
# Arguments:
#   None (takes 0 arguments)
#
# Outputs:
#   Writes the compact JSON object from UAPI `.data` to stdout:
#   {"main_domain":"...","addon_domains":[...],"sub_domains":[...],"parked_domains":[...]}
#
# Returns:
#   0 on success, non-zero on validation, transport, or UAPI error.
#
# Example:
#   domains_json="$(cpanel_domain_info_list_domains)"
#   printf '%s\n' "$domains_json" | jq -r '.main_domain'
cpanel_domain_info_list_domains() {
    assert_cmds jq
    assert_argc 0 $#

    log_verbose "Requesting cPanel domain list (DomainInfo/list_domains)"

    local response
    if ! response="$(send_cpanel_uapi_request "GET" "DomainInfo" "list_domains")"; then
        log_verbose "cPanel DomainInfo/list_domains request failed"
        return 1
    fi

    local domains_data
    if ! domains_data="$(printf '%s' "$response" | jq -ec '.data | select(type == "object")' 2>/dev/null)"; then
        log_err "cPanel UAPI DomainInfo/list_domains returned invalid or non-object 'data' payload."
        return 1
    fi

    log_verbose "cPanel DomainInfo/list_domains succeeded"
    printf '%s\n' "$domains_data"
    return 0
}

_DAH_CPANEL_DOMAIN_INFO_SH=1