#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Validate and publish the Dynamic Email Router flow with the Archy CLI.
#   Docs: https://developer.genesys.cloud/devapps/archy/
#
# Auth: Archy reads GENESYSCLOUD_OAUTHCLIENT_ID / _SECRET / _REGION, or pass
#       --clientId / --clientSecret / --location explicitly.
#
# Usage:
#   ./scripts/deploy-flow.sh            # validate + create/replace
#   ./scripts/deploy-flow.sh validate   # validate only
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLOW="${ROOT}/flows/dynamic-email-router.yaml"

if ! command -v archy >/dev/null 2>&1; then
  echo "ERROR: archy CLI not found. Install: https://developer.genesys.cloud/devapps/archy/" >&2
  exit 1
fi

echo ">> Validating ${FLOW}"
archy validate --file "${FLOW}"

if [[ "${1:-deploy}" == "validate" ]]; then
  echo ">> Validation passed (validate-only mode)."
  exit 0
fi

echo ">> Publishing flow (create or replace existing by name)"
archy create --file "${FLOW}" --forceUnlock --recreateOnFail
echo ">> Done. Assign this flow to your Inbound Email Route(s) under Admin > Routing > Email."
