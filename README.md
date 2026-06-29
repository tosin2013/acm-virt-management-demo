# ACM Virtual Machine Management Demo

A Red Hat Showroom demo covering multicluster governance and virtualization lifecycle with Red Hat Advanced Cluster Management (RHACM) and OpenShift Virtualization.

## Demo Modules

1. **VM Policies and Governance** -- Declarative VM governance via ACM ConfigurationPolicies
2. **Fleet Observability** -- Centralized Grafana dashboards for VM metrics across clusters
3. **Application Topology Views** -- Visual dependency graphs and remote log retrieval
4. **Deploy Without Cluster-Admin** -- GitOps workflows using `subscription-admin`
5. **Fine-Grained ACM Permissions** -- ClusterPermission API for scoped kubevirt.io roles
6. **Eradicate Cluster Destruction** -- Custom RBAC preventing managed cluster deletion

## Structure

```
content/          Antora/AsciiDoc Showroom lab content
policies/         ACM policy manifests (GitOps-ready)
rbac/             RBAC manifests (ClusterRole, ClusterPermission)
```

## Local Preview

```bash
cd content
podman run --rm --name antora -v $PWD:/antora:z -p 8080:8080 -i -t \
  ghcr.io/juliaaano/antora-viewer
```

Open http://localhost:8080

## Target Environment

Domain: `.sandbox3008.opentlc.com`
