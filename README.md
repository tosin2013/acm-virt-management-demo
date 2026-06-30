# ACM Virtual Machine Management Demo

[![Build and Deploy](https://github.com/tosin2013/acm-virt-management-demo/actions/workflows/deploy-pages.yml/badge.svg)](https://github.com/tosin2013/acm-virt-management-demo/actions/workflows/deploy-pages.yml)

**Live Site:** https://tosin2013.github.io/acm-virt-management-demo

A Red Hat Showroom demo covering multicluster governance and virtualization lifecycle with Red Hat Advanced Cluster Management (RHACM) and OpenShift Virtualization.

## Demo Modules

1. **Deploy VM Workloads** -- Fedora VMs via GitOps and Windows VMs via ISO-based installation
2. **Application Topology Views** -- Visual dependency graphs and remote log retrieval
3. **VM Policies and Governance** -- Declarative VM governance via ACM ConfigurationPolicies
4. **Fleet Observability** -- Centralized Grafana dashboards for VM metrics across clusters
5. **VM Right-Sizing Recommendations** -- RHACM 2.16 right-sizing dashboards with observe-resize-verify workflow
6. **Deploy Without Cluster-Admin** -- GitOps workflows using `subscription-admin`
7. **Fine-Grained ACM Permissions** -- ClusterPermission API for scoped kubevirt.io roles
8. **Eradicate Cluster Destruction** -- Custom RBAC preventing managed cluster deletion

## Structure

```
content/                    Antora/AsciiDoc Showroom lab content
policies/                   ACM policy manifests (GitOps-ready)
rbac/                       RBAC manifests (ClusterRole, ClusterPermission)
right-sizing/               ACM right-sizing policies and Grafana dashboard ConfigMaps
components/httpd-fileserver/ In-cluster HTTP file server for ISO hosting (OAuth-secured UI)
ansible/roles/              AgnosticD workload roles for automated deployment
```

## Local Preview

```bash
# Using the included utilities (recommended)
./utilities/lab-build    # build the site
./utilities/lab-serve    # serve at http://localhost:8080
./utilities/lab-stop     # stop the server

# Or using podman-compose
podman-compose up
```

Open http://localhost:8080

## Deployment

See [agnosticd/DEPLOYMENT.md](agnosticd/DEPLOYMENT.md) for full setup instructions.

Quick start (requires AgnosticD v2 + AWS credentials):

```bash
cd ~/Development/agnosticd-v2-vars/acm-virt-management-demo
./deploy.sh
```

## Target Environment

Domain: `.sandbox3008.opentlc.com`
