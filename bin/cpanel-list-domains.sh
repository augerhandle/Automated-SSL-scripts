#!/usr/bin/env bash
set -euo pipefail

bash -c 'source lib/cpanel_domain_info.sh && cpanel_domain_info_list_domains | jq .'