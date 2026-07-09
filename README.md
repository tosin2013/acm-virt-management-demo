# ACM Virtual Machine Management Demo

[![Build and Deploy](https://github.com/tosin2013/acm-virt-management-demo/actions/workflows/deploy-pages.yml/badge.svg)](https://github.com/tosin2013/acm-virt-management-demo/actions/workflows/deploy-pages.yml)

**Live Site:** https://tosin2013.github.io/acm-virt-management-demo

A Red Hat Showroom demo covering multicluster governance and virtualization lifecycle with Red Hat Advanced Cluster Management (RHACM) and OpenShift Virtualization.

## Demo Modules

1. **Deploy VM Workloads** -- Fedora VMs via GitOps and Windows VMs via ISO-based installation
2. **Application Topology Views** -- Visual dependency graphs and remote log retrieval
3. **VM Policies and Governance** -- Declarative VM governance via ACM ConfigurationPolicies
4. **Fleet Observability** -- Centralized Grafana dashboards for VM metrics across clusters
5. **VM Right-Sizing Recommendations** -- RHACM right-sizing dashboards with observe-resize-verify workflow
6. **Deploy Without Cluster-Admin** -- GitOps workflows using `subscription-admin`
7. **Fine-Grained ACM Permissions** -- MulticlusterRoleAssignment API for scoped kubevirt.io roles
8. **Eradicate Cluster Destruction** -- Custom RBAC preventing managed cluster deletion

## Getting Started

```bash
git clone https://github.com/tosin2013/acm-virt-management-demo.git
cd acm-virt-management-demo
make setup        # interactive wizard — installs tools, configures deployment
make deploy       # provision hub + student clusters (1-2 hours)
```

Or open the project in **Cursor** / **Claude Code** and type `/onboard` for
AI-assisted setup.

See [agnosticd/QUICKSTART.md](agnosticd/QUICKSTART.md) for the full 5-step
guide or [agnosticd/DEPLOYMENT.md](agnosticd/DEPLOYMENT.md) for the advanced
reference.

## Structure

```
content/                    Antora/AsciiDoc Showroom lab content
policies/                   ACM policy manifests (GitOps-ready)
rbac/                       RBAC manifests (ClusterRole, MulticlusterRoleAssignment, Placement)
right-sizing/               ACM right-sizing policies and Grafana dashboard ConfigMaps
components/httpd-fileserver/ In-cluster HTTP file server for ISO hosting (OAuth-secured UI)
ansible/roles/              AgnosticD workload roles for automated deployment
agnosticd/                  Deployment scripts, onboard manifest, and config templates
```

## Local Preview

```bash
make docs-build   # build the site
make docs-serve   # serve at http://localhost:8080
make docs-stop    # stop the server
```

Open http://localhost:8080
