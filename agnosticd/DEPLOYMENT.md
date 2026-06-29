# AgnosticD Deployment Guide

## Prerequisites

| Requirement | Version | Check |
|-------------|---------|-------|
| Python | 3.12+ | `python3 --version` |
| Podman | 5.x+ | `podman --version` |
| AWS credentials | - | `ls ~/.aws/credentials` |
| AgnosticD v2 | main | `ls ~/Development/agnosticd-v2/bin/agd` |

## Setup

```bash
cd ~/Development/agnosticd-v2
./bin/agd setup
```

This creates:
- `agnosticd-v2-vars/` -- configuration variables
- `agnosticd-v2-secrets/` -- cloud credentials
- `agnosticd-v2-output/` -- deployment logs
- `agnosticd-v2-virtualenv/` -- Python environment

## Secrets Configuration

Copy your sandbox secrets file:

```bash
cp agnosticd-v2-secrets/secrets-sandboxXXX.yml agnosticd-v2-secrets/secrets-sandbox3008.yml
```

Fill in:
- `aws_access_key_id`
- `aws_secret_access_key`
- `base_domain: sandbox3008.opentlc.com`

## Deployment

The deployment scripts live in `agnosticd-v2-vars/acm-virt-management-demo/`.

### Deploy (Hub + Student Clusters)

```bash
cd ~/Development/agnosticd-v2-vars/acm-virt-management-demo
./deploy.sh
```

Environment variables:
- `NUM_STUDENTS=2` -- number of student clusters (default: 2)
- `PARALLEL=false` -- parallel provisioning (default: false)
- `DEPLOY_HUB=true` -- deploy the RHACM hub (default: true)

### Stop / Start / Status

```bash
./stop.sh      # stop all clusters (cost savings)
./start.sh     # restart stopped clusters
```

### Teardown

```bash
./teardown.sh  # destroy all clusters (confirms before proceeding)
```

## Workload Role

The `ocp4_workload_acm_virt_demo` role in the agnosticd-v2 fork handles:

1. Creating policy and VM namespaces
2. Labeling managed clusters with `virtualization-enabled: true`
3. Applying all policy YAML from this repo's `policies/` directory
4. Applying all RBAC manifests from this repo's `rbac/` directory
5. Reporting deployment info via `agnosticd_user_info`

Add it to your vars file:

```yaml
workloads:
  - ocp4_workload_acm_virt_demo
```

## Hub Cluster Components

The hub cluster vars file (`acm-virt-hub.yaml`) provisions:

| Component | Purpose |
|-----------|---------|
| RHACM 2.12 | Multicluster governance |
| OpenShift Virtualization | KVM-based VM hosting |
| OpenShift GitOps | ArgoCD for declarative deployment |
| OADP 1.4 | Velero-based VM backup |
| cert-manager | TLS certificate automation |
| Showroom | Interactive demo lab guide |

Worker nodes use `m5.metal` instance type for bare-metal KVM support.
