#!/bin/bash
# Validates that the Windows Server 2019 ISO is uploaded and accessible
# on the in-cluster HTTP file server.
#
# Usage:
#   ./validate-iso.sh                          # auto-detect (must be logged into student cluster)
#   ./validate-iso.sh <ingress-domain>         # explicit ingress domain
#
# Exit codes:
#   0 = ISO is present and accessible
#   1 = ISO is missing or inaccessible

set -euo pipefail

ISO_FILENAME="${ISO_FILENAME:-win2k19.iso}"
NAMESPACE="${NAMESPACE:-httpd-server}"
DEPLOY_NAME="${DEPLOY_NAME:-httpd-fileserver}"
INTERNAL_SVC="http://httpd-server.${NAMESPACE}.svc.cluster.local:8080/files/${ISO_FILENAME}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

ERRORS=0

echo "=== HTTP File Server — ISO Validation ==="
echo ""

# Check 1: File server pod is running
info "Checking file server pod..."
POD_STATUS=$(oc get deploy "${DEPLOY_NAME}" -n "${NAMESPACE}" --no-headers -o custom-columns=':status.readyReplicas' 2>/dev/null || echo "0")
if [[ "${POD_STATUS}" == "1" ]]; then
  pass "File server deployment is ready (${DEPLOY_NAME})"
else
  fail "File server deployment not ready (readyReplicas=${POD_STATUS})"
  ERRORS=$((ERRORS + 1))
fi

# Check 2: ISO file exists on disk
info "Checking ISO file on disk (/data/${ISO_FILENAME})..."
FILE_SIZE=$(oc exec -n "${NAMESPACE}" "deploy/${DEPLOY_NAME}" -c "${DEPLOY_NAME}" -- \
  stat -c '%s' "/data/${ISO_FILENAME}" 2>/dev/null || echo "0")
if [[ "${FILE_SIZE}" -gt 1000000000 ]]; then
  SIZE_GB=$(awk "BEGIN {printf \"%.1f\", ${FILE_SIZE}/1073741824}")
  pass "ISO file exists on disk (${SIZE_GB} GB)"
else
  fail "ISO file missing or too small (${FILE_SIZE} bytes) — upload via the web UI"
  ERRORS=$((ERRORS + 1))
fi

# Check 3: ISO accessible via internal HTTP endpoint
info "Checking internal HTTP access (${INTERNAL_SVC})..."
HTTP_CODE=$(oc run iso-check-$$ --rm -i --restart=Never --image=registry.access.redhat.com/ubi9/ubi-minimal \
  -- curl -s -o /dev/null -w '%{http_code}' "${INTERNAL_SVC}" 2>/dev/null | grep -oE '^[0-9]{3}' | head -1)
if [[ "${HTTP_CODE}" == "200" ]]; then
  pass "ISO accessible via internal service (HTTP ${HTTP_CODE})"
else
  fail "ISO not accessible via internal service (HTTP ${HTTP_CODE}) — expected 200"
  ERRORS=$((ERRORS + 1))
fi

# Check 4: External route exists
info "Checking external route..."
if [[ -n "${1:-}" ]]; then
  INGRESS_DOMAIN="$1"
else
  INGRESS_DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "")
fi
ROUTE_HOST=$(oc get route httpd-server -n "${NAMESPACE}" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [[ -n "${ROUTE_HOST}" ]]; then
  pass "External route exists: https://${ROUTE_HOST}"
else
  fail "No external route found for file server"
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=== Summary ==="
if [[ ${ERRORS} -eq 0 ]]; then
  pass "All checks passed — ISO is ready for DataVolume imports"
  exit 0
else
  fail "${ERRORS} check(s) failed — see above"
  echo ""
  echo "To upload the ISO:"
  echo "  1. Open https://${ROUTE_HOST:-httpd-server-httpd-server.<ingress-domain>}"
  echo "  2. Log in with OpenShift OAuth credentials"
  echo "  3. Upload the Windows Server 2019 ISO as '${ISO_FILENAME}'"
  exit 1
fi
