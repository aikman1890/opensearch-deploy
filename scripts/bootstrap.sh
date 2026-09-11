#!/usr/bin/env bash
#
# bootstrap.sh — wait for the OpenSearch cluster to reach green status,
# then install the ISM lifecycle policy for logs-* indices.
#
# Usage: OPENSEARCH_URL=https://opensearch:9200 ./scripts/bootstrap.sh
#
set -euo pipefail

OPENSEARCH_URL="${OPENSEARCH_URL:-https://localhost:9200}"
OPENSEARCH_USER="${OPENSEARCH_USER:-admin}"
OPENSEARCH_PASSWORD="${OPENSEARCH_PASSWORD:?Set OPENSEARCH_PASSWORD to the admin password}"
POLICY_FILE="$(dirname "$0")/../kubernetes/ism-policy.json"
POLICY_ID="sre-logs-lifecycle"

echo "Waiting for ${OPENSEARCH_URL} to reach green status..."

attempt=0
max_attempts=60
while true; do
  attempt=$((attempt + 1))
  status="$(curl -sS -k -u "${OPENSEARCH_USER}:${OPENSEARCH_PASSWORD}" \
    "${OPENSEARCH_URL}/_cluster/health?wait_for_status=green&timeout=30s" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status", "unknown"))' \
    || echo "unreachable")"

  if [ "${status}" = "green" ]; then
    echo "Cluster is green."
    break
  fi

  if [ "${attempt}" -ge "${max_attempts}" ]; then
    echo "ERROR: cluster did not reach green status after ${max_attempts} attempts." >&2
    exit 1
  fi

  echo "Attempt ${attempt}/${max_attempts}: cluster status is '${status}' — retrying in 30s..."
  sleep 30
done

echo "Installing ISM policy '${POLICY_ID}' from ${POLICY_FILE}..."
curl -sS -k -u "${OPENSEARCH_USER}:${OPENSEARCH_PASSWORD}" \
  -X PUT "${OPENSEARCH_URL}/_plugins/_ism/policies/${POLICY_ID}" \
  -H "Content-Type: application/json" \
  -d @"${POLICY_FILE}" | python3 -m json.tool

echo "Done."
