#!/bin/bash
# Validates that the ACM Fleet Virtualization view is properly configured
# on the hub cluster and can detect VMs from managed clusters.
#
# Usage:
#   ./validate-fleet-virt.sh                # must be logged into hub cluster
#
# Exit codes:
#   0 = Fleet virtualization view is ready
#   1 = One or more checks failed

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

ERRORS=0

echo "=== ACM Fleet Virtualization — Validation ==="
echo ""

# Check 1: CNV operator installed on hub
info "Checking OpenShift Virtualization operator on hub..."
CSV_PHASE=$(oc get csv -n openshift-cnv -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "${CSV_PHASE}" == "Succeeded" ]]; then
  pass "OpenShift Virtualization operator is installed (phase=Succeeded)"
else
  fail "OpenShift Virtualization operator not ready (phase=${CSV_PHASE})"
  ERRORS=$((ERRORS + 1))
fi

# Check 2: kubevirt-plugin ConsolePlugin enabled
info "Checking kubevirt-plugin ConsolePlugin..."
PLUGINS=$(oc get consoles.operator.openshift.io cluster -o jsonpath='{.spec.plugins[*]}' 2>/dev/null || echo "")
if echo "$PLUGINS" | grep -qw "kubevirt-plugin"; then
  pass "kubevirt-plugin ConsolePlugin is enabled"
else
  fail "kubevirt-plugin ConsolePlugin is NOT enabled"
  echo "      Fix: oc patch consoles.operator.openshift.io cluster --type=json -p='[{\"op\":\"add\",\"path\":\"/spec/plugins/-\",\"value\":\"kubevirt-plugin\"}]'"
  ERRORS=$((ERRORS + 1))
fi

# Check 3: cnv-mtv-integrations enabled in MultiClusterHub
info "Checking cnv-mtv-integrations component in MultiClusterHub..."
MCH_COMPONENTS=$(oc get multiclusterhub multiclusterhub -n open-cluster-management -o json 2>/dev/null | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
comps=data.get('spec',{}).get('overrides',{}).get('components',[])
for c in comps:
  if c.get('name')=='cnv-mtv-integrations':
    print('enabled' if c.get('enabled') else 'disabled')
    sys.exit()
print('missing')
" 2>/dev/null || echo "error")
if [[ "${MCH_COMPONENTS}" == "enabled" ]]; then
  pass "cnv-mtv-integrations component is enabled"
else
  fail "cnv-mtv-integrations component is ${MCH_COMPONENTS}"
  ERRORS=$((ERRORS + 1))
fi

# Check 4: search-collector addon on managed clusters
info "Checking search-collector addon on managed clusters..."
MANAGED_CLUSTERS=$(oc get managedclusters -l vendor=OpenShift --no-headers -o custom-columns=':metadata.name' 2>/dev/null | grep -v "local-cluster" || echo "")
if [[ -z "$MANAGED_CLUSTERS" ]]; then
  fail "No managed clusters found (excluding local-cluster)"
  ERRORS=$((ERRORS + 1))
else
  for cluster in $MANAGED_CLUSTERS; do
    ADDON_AVAIL=$(oc get managedclusteraddon search-collector -n "$cluster" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
    if [[ "${ADDON_AVAIL}" == "True" ]]; then
      pass "search-collector addon available on ${cluster}"
    else
      fail "search-collector addon not available on ${cluster} (status=${ADDON_AVAIL})"
      ERRORS=$((ERRORS + 1))
    fi
  done
fi

# Check 5: VMs visible in hub search API
info "Checking VM resources in hub search index..."
SEARCH_ROUTE=$(oc get route search-api -n open-cluster-management -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [[ -z "$SEARCH_ROUTE" ]]; then
  SEARCH_ROUTE=$(oc get route search-api -n open-cluster-management-global-set -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
fi
if [[ -n "$SEARCH_ROUTE" ]]; then
  TOKEN=$(oc whoami -t 2>/dev/null || echo "")
  VM_COUNT=$(curl -sk -H "Authorization: Bearer $TOKEN" \
    "https://${SEARCH_ROUTE}/searchapi/v1/search" \
    -H "Content-Type: application/json" \
    -d '{"query":"kind:VirtualMachine"}' 2>/dev/null | \
    python3 -c "import sys,json; data=json.load(sys.stdin); print(len(data.get('items',data.get('related',[]))))" 2>/dev/null || echo "0")
  if [[ "${VM_COUNT}" -gt 0 ]]; then
    pass "Found ${VM_COUNT} VirtualMachine resource(s) in hub search index"
  else
    info "No VMs currently indexed — VMs may not be deployed yet (non-blocking)"
  fi
else
  info "Could not determine search API route — skipping search index check"
fi

# Check 6: Search annotation for VM preview
info "Checking search-v2-operator VM preview annotation..."
VM_PREVIEW=$(oc get search search-v2-operator -n open-cluster-management -o jsonpath='{.metadata.annotations.virtual-machine-preview}' 2>/dev/null || echo "")
if [[ "${VM_PREVIEW}" == "true" ]]; then
  pass "search-v2-operator has virtual-machine-preview=true annotation"
else
  fail "search-v2-operator missing virtual-machine-preview annotation"
  echo "      Fix: oc annotate search search-v2-operator -n open-cluster-management virtual-machine-preview='true'"
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=== Summary ==="
if [[ ${ERRORS} -eq 0 ]]; then
  pass "All checks passed — Fleet Virtualization view is ready"
  echo ""
  echo "To access: Hub Console → Fleet management view → Infrastructure → Virtual machines"
  exit 0
else
  fail "${ERRORS} check(s) failed — see above for remediation steps"
  exit 1
fi
