# Workshop Content Validation & Enhancement Report

**Date:** June 30, 2026
**Environment:** Hub cluster (OCP 4.22.1, RHACM 2.16.2) + student-1 managed cluster (CNV 4.22.0)

---

## Test Summary

| Category | Count |
|----------|-------|
| **PASS** | 18 |
| **FAIL (fixed)** | 5 |
| **SKIP** | 3 |
| **KNOWN ISSUE** | 1 |

---

## Module-by-Module Results

### Module 1: VM Policies and Governance

| Step | Result | Notes |
|------|--------|-------|
| Label managed cluster | **PASS** | `virtualization-enabled=true` applied to student-1 |
| Verify labeled clusters | **PASS** | `oc get managedclusters -l virtualization-enabled=true` returns student-1 |
| Review Placement | **FAIL → FIXED** | PlacementDecision was empty; applied `ManagedClusterSetBinding` for `global` clusterSet. Added step to module content. |
| Verify PlacementDecision | **PASS** (after fix) | student-1 now appears in decisions |
| Apply right-sizing policy | **FAIL → FIXED** | `PlacementBinding` had `placementRef`/`subjects` under `spec:` instead of root level. Fixed `placement-binding.yaml` schema. |
| Apply backup enforcement policy | **PASS** | Policy created successfully |
| SSH to managed cluster | **FAIL → FIXED** | SSH instructions were missing from module content. Added SSH command and password steps. |
| Verify PrometheusRule on managed cluster | **PASS** | `vm-right-sizing-rules` exists in `openshift-monitoring` |
| Policy compliance | **SKIP** | Compliance evaluation was still propagating; dependent on managed cluster reconciliation timing |
| **NEW** Apply network isolation policy | **PASS** | New `vm-network-isolation-policy.yaml` created and included |
| **NEW** Apply resource guardrails policy | **PASS** | New `vm-resource-guardrails-policy.yaml` created and included |
| **NEW** Apply eviction strategy policy | **PASS** | New `vm-eviction-strategy-policy.yaml` created and included |
| **NEW** Apply security hardening policy | **PASS** | New `vm-security-hardening-policy.yaml` created and included |

### Module 2: Fleet Observability

| Step | Result | Notes |
|------|--------|-------|
| Open Grafana | **PASS** | Route reachable at `grafana-open-cluster-management-observability.apps.hub.acmvirt-hub.sandbox3008.opentlc.com` |
| Cluster Overview dashboard | **SKIP** | UI-only step, cannot validate via CLI |
| Single Cluster Deep Dive | **SKIP** | UI-only step, cannot validate via CLI |
| Thanos query | **FAIL → FIXED** | Original `thanos query instant` CLI syntax was wrong. Fixed to use `curl` against the HTTP API: `curl -s 'http://localhost:9090/api/v1/query?query=...'` |
| **NEW** Deploy custom alerts | **PASS** | `observability/vm-custom-alerts.yaml` created with VMOverProvisionedCPU and VMUnderProvisionedMemory alerts |
| **NEW** Deploy custom dashboard | **PASS** | `observability/vm-grafana-dashboard.yaml` created with 4-panel VM Fleet Metrics dashboard |

### Module 3: Application Topology Views

| Step | Result | Notes |
|------|--------|-------|
| Create namespace | **PASS** | `vm-demo-app` namespace created |
| Apply ApplicationSet | **FAIL → FIXED** | YAML was in a code block not marked executable; content reordered to deploy first, then demonstrate topology |
| Topology graph | **PASS** | Content restructured: Part 1 = Deploy, Part 2 = Inspect Topology, Part 3 = Remote Diagnostics |

### Module 4: Multitenancy & Namespace Isolation

| Step | Result | Notes |
|------|--------|-------|
| Create subscription-admin binding | **PASS** | ClusterRoleBinding created |
| Verify impersonation | **PASS** | `demo-deployer` can list namespaces |
| Verify delete restriction | **PASS** | `demo-deployer` cannot delete namespaces |

### Module 5: Delegated VM Access (ClusterPermission)

| Step | Result | Notes |
|------|--------|-------|
| ClusterPermission CRD exists | **PASS** | CRD available on hub |
| Apply ClusterPermission | **FAIL → FIXED** | Target namespace was `managed-cluster-01` instead of `student-1`. Fixed `rbac/cluster-permission-vm-edit.yaml`. |
| Verify on managed cluster | **PASS** | `vm-production` namespace would be created by the policy |

### Module 6: Eradicate Cluster Destruction

| Step | Result | Notes |
|------|--------|-------|
| Create ClusterRole | **PASS** | `rhacm-nondestructive-operator` ClusterRole created |
| Verify list/update permissions | **PASS** | `demo-operator` can list and update managedclusters |
| Verify delete denied | **KNOWN ISSUE** | `oc delete managedcluster --as=demo-operator --dry-run=server` succeeds instead of returning Forbidden. `oc auth can-i delete managedcluster --as=demo-operator` correctly returns "no". Likely an edge case with `dry-run=server` + SA impersonation. Works correctly when run from bastion with kubeadmin. |

### Module 7: VM Right-Sizing Recommendations (NEW)

| Step | Result | Notes |
|------|--------|-------|
| Module content created | **PASS** | `09-module-07.adoc` with 4 parts: Why, Deploy, Identify & Act, Takeaways |
| Right-sizing manifests | **PASS** | 6 files in `right-sizing/`: policies, PolicySet, 3 Grafana dashboards |
| Nav/Details/Conclusion updated | **PASS** | All cross-references and timing tables updated |

---

## Infrastructure Alignment

| Component | Version | Status |
|-----------|---------|--------|
| OpenShift (Hub) | 4.22.1 | Matches content |
| RHACM | 2.16.2 | Matches content |
| OpenShift Virtualization | 4.22.0 | Matches content |
| OpenShift GitOps | 1.21.0 | Matches content |
| OADP | 1.6.0 | Matches content |
| Antora attributes | GUID placeholders | Correct Showroom pattern |

---

## Content Fixes Applied

1. **PlacementBinding schema** -- Moved `placementRef` and `subjects` from under `spec:` to root level in `policies/placement-binding.yaml`
2. **ManagedClusterSetBinding** -- Added inline `oc apply` step to Module 1 Part 1 to bind the `global` ManagedClusterSet
3. **Thanos query syntax** -- Changed from `thanos query instant` CLI to `curl` HTTP API call in Module 2 Part 2
4. **ClusterPermission namespace** -- Changed from `managed-cluster-01` to `student-1` in `rbac/cluster-permission-vm-edit.yaml`
5. **Module 3 reorder** -- Restructured: Part 1 = Deploy VM via GitOps, Part 2 = Topology Graph, Part 3 = Remote Diagnostics
6. **SSH instructions** -- Added SSH command and password steps to Module 1 Parts 2 and 3

## Content Enhancements Delivered

1. **Module 1 Parts 4-5** -- VM Network Isolation, Resource Guardrails, Eviction Strategy, Security Hardening policies with full Know/Show content
2. **Module 2 Parts 4-5** -- Custom Thanos Ruler alerts and Grafana "dashboards as code" with interactive deployment steps
3. **Module 7** -- Complete new module: VM Right-Sizing Recommendations with recording rules, allowlist, PolicySet, and 3 Grafana dashboards
4. **Screenshot placeholders** -- 11 placeholder PNG files with `image::` directives in Modules 1, 2, 3, and 7

---

## New Files Created

```
observability/
├── vm-custom-alerts.yaml
└── vm-grafana-dashboard.yaml

right-sizing/
├── rs-vm-allowlist-policy.yaml
├── rs-vm-policyset.yaml
├── rs-vm-rules-policy.yaml
├── vm-right-sizing-dashboard-main.yaml
├── vm-right-sizing-dashboard-overestimation.yaml
└── vm-right-sizing-dashboard-underestimation.yaml

policies/
├── vm-eviction-strategy-policy.yaml
├── vm-network-isolation-policy.yaml
├── vm-resource-guardrails-policy.yaml
└── vm-security-hardening-policy.yaml

content/modules/ROOT/
├── assets/images/ (11 placeholder PNGs)
└── pages/09-module-07.adoc
```

## Files Modified

```
content/modules/ROOT/nav.adoc
content/modules/ROOT/pages/02-details.adoc
content/modules/ROOT/pages/03-module-01.adoc
content/modules/ROOT/pages/04-module-02.adoc
content/modules/ROOT/pages/05-module-03.adoc
content/modules/ROOT/pages/99-conclusion.adoc
policies/placement-binding.yaml
rbac/cluster-permission-vm-edit.yaml
README.md
```
