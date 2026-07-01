#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Create the Email Routing data table and bulk-load rows from the sample CSV
# using the Genesys Cloud CLI (gc).
#   Docs: https://developer.genesys.cloud/devapps/cli/
#
# Auth: `gc profiles` / GC_* env vars, or run `gc login` first.
#
# Usage:
#   ./scripts/import-datatable.sh                       # create table + import CSV
#   ./scripts/import-datatable.sh <datatableId>          # import CSV into existing table
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="${ROOT}/data-tables/email-routing.schema.json"
CSV="${ROOT}/data-tables/email-routing.sample.csv"

if ! command -v gc >/dev/null 2>&1; then
  echo "ERROR: Genesys Cloud CLI (gc) not found. Install: https://developer.genesys.cloud/devapps/cli/" >&2
  exit 1
fi

DT_ID="${1:-}"
if [[ -z "${DT_ID}" ]]; then
  echo ">> Creating 'Email Routing' data table from ${SCHEMA}"
  DT_ID="$(gc flows datatables create -f "${SCHEMA}" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')"
  echo ">> Created data table id=${DT_ID}"
fi

echo ">> Importing rows from ${CSV}"
# The CLI has no native CSV import; convert each CSV line to a row create call.
python3 - "$DT_ID" "$CSV" <<'PY'
import csv, json, subprocess, sys
dt_id, csv_path = sys.argv[1], sys.argv[2]
def coerce(k, v):
    if k in ("priority",):                       return int(v or 0)
    if k in ("autoReplyEnabled", "enabled"):     return str(v).strip().lower() == "true"
    return v
with open(csv_path, newline="") as fh:
    for row in csv.DictReader(fh):
        body = {k: coerce(k, v) for k, v in row.items()}
        subprocess.run(
            ["gc", "flows", "datatables", "rows", "create", "--datatableId", dt_id, "-f", "/dev/stdin"],
            input=json.dumps(body), text=True, check=True,
        )
        print(f"   + {row['key']}")
PY
echo ">> Import complete for data table ${DT_ID}"
