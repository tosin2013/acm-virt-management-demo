# AgnosticD Deployment Guide

## Prerequisites

| Requirement | Version | Check |
|-------------|---------|-------|
| Python | 3.12+ | `python3 --version` |
| Podman | 5.x+ | `podman --version` |
| AWS credentials | - | `ls ~/.aws/credentials` |
| OpenShift pull secret | - | `cat ~/pull-secret.json` |
| AgnosticD v2 | main | `ls ~/Development/agnosticd-v2/bin/agd` |

## AWS Quota Pre-flight

**Run this before every deployment.** The demo uses `m5.metal` workers (96 vCPUs each),
which requires significant AWS quota.

```bash
cd ~/acm-virt-management-demo
./agnosticd/check-quota.sh
```

Override defaults with environment variables:

```bash
AWS_REGION=us-west-2 NUM_STUDENTS=4 WORKER_TYPE=m5.metal ./agnosticd/check-quota.sh
```

### Minimum Quotas (default: 2 clusters — 1 hub + 1 student)

| Resource | Hub (m5.metal) | Student (m5.2xlarge) | Total (2) | Default Quota | Action |
|----------|----------------|----------------------|-----------|---------------|--------|
| On-Demand vCPUs | 302 | 46 | 348 | 528 | OK (increase if adding students) |
| Elastic IPs | 2 | 2 | 4 | 5 | OK (increase if adding students) |
| VPCs | 1 | 1 | 2 | 5 | OK |
| NAT Gateways | 1 | 1 | 2 | 5 | OK |
| NLBs | 2 | 2 | 4 | 50 | OK |

To request increases: [AWS Service Quotas Console](https://console.aws.amazon.com/servicequotas/)

> **Tip:** The default (1 hub + 1 student) fits within standard AWS quotas.
> For a hub-only demo use `NUM_STUDENTS=0 ./deploy.sh`. For multiple students,
> check quotas first: `NUM_STUDENTS=3 ./agnosticd/check-quota.sh`.

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

The deployment is fully automated through a single script. It provisions the hub
cluster, deploys all workloads, creates student clusters, registers them with
RHACM, and generates a `student-info.txt` summary — no manual `oc` commands needed.

### How It Works

1. **Symlink setup** — `deploy.sh` ensures `agd` always reads the canonical vars
   files from `acm-virt-management-demo/` by creating symlinks for both the hub
   and student configs
2. **Pull secret injection** — Reads `~/pull-secret.json` and injects it into
   `secrets.yml` if the placeholder is still present
3. **Hub deployment** — Runs `agd provision` with the hub config which installs
   all operators (Showroom is not in the `workloads` list — it is deferred)
4. **Student deployment** — For each student, generates a per-student vars file
   merging the student template with hub API URL and token, then runs
   `agd provision`
5. **RHACM auto-import** — The `ocp4_workload_rhacm_import` role creates a
   `ManagedCluster` CR and auto-import secret on the hub, then waits for the spoke
   to become available
6. **Showroom deployment** — After all students are up, generates a hub vars file
   that overrides `workloads` to `[showroom]` and appends student cluster data
   (bastion hosts, API URLs, console URLs). Runs `agd provision` on the hub again;
   only Showroom executes, with student data injected as Antora attributes
7. **Info generation** — Reads `provision-user-data.yaml` for each GUID and writes
   a formatted `student-info.txt`
8. **Idempotent re-runs** — The `install_operator` role checks for an existing
   `Succeeded` CSV and skips operators that are already installed, making
   `agd provision` safe to re-run after partial failures

### Deploy (Hub + Student Clusters)

```bash
cd ~/Development/agnosticd-v2-vars/acm-virt-management-demo
./deploy.sh
```

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `NUM_STUDENTS` | `1` | Number of student clusters |
| `PARALLEL` | `false` | Parallel student provisioning |
| `DEPLOY_HUB` | `true` | Deploy the RHACM hub cluster |
| `DEPLOY_SHOWROOM` | `true` | Deploy Showroom after students (with their data) |
| `HUB_GUID` | `acmvirt-hub` | GUID for the hub cluster |
| `ACCOUNT` | `sandbox3008` | AgnosticD account name |
| `SKIP_QUOTA_CHECK` | `false` | Bypass quota pre-flight |

### Hub-only Deployment

```bash
NUM_STUDENTS=0 ./deploy.sh
```

### Re-running After a Partial Failure

Simply re-run `./deploy.sh`. Already-installed operators are detected and skipped
automatically. The script picks up where it left off.

```bash
# Skip hub if already deployed
DEPLOY_HUB=false ./deploy.sh
```

### Monitoring Logs

```bash
tail -f ~/Development/agnosticd-v2-output/acmvirt-hub/acmvirt-hub.log
```

### Stop / Start / Status

```bash
./stop.sh      # stop all clusters (cost savings)
./start.sh     # restart stopped clusters
```

### Teardown

```bash
./teardown.sh  # destroy all clusters (confirms before proceeding)
```

## Architecture

### Hub Cluster (`acm-virt-hub.yaml`)

| Component | Purpose |
|-----------|---------|
| RHACM 2.16 | Multicluster governance (VM right-sizing, cross-cluster live migration) |
| OpenShift Virtualization | KVM-based VM hosting |
| OpenShift GitOps | ArgoCD for declarative deployment |
| OADP | Velero-based VM backup |
| cert-manager | TLS certificate automation |
| Showroom | Interactive demo lab guide |

Worker nodes use `m5.metal` instance type for bare-metal KVM support.

### Student Clusters (`acm-virt-student.yaml`)

| Component | Purpose |
|-----------|---------|
| cert-manager | TLS certificate automation |
| htpasswd auth | Student user accounts |
| RHACM Import | Auto-registers spoke with hub RHACM |

Worker nodes use `m5.2xlarge` (lighter than hub — no bare-metal needed).

### Custom Roles

| Role | Location | Purpose |
|------|----------|---------|
| `ocp4_workload_oadp` | `ansible/roles/ocp4_workload_oadp/` | Installs OADP operator with idempotency |
| `ocp4_workload_rhacm_import` | `ansible/roles/ocp4_workload_rhacm_import/` | Imports spoke cluster into RHACM hub |
| `install_operator` (modified) | `ansible/roles/install_operator/` | Added CSV pre-check for idempotent installs |

## Output Files

After deployment, find these in the vars directory:

| File | Contents |
|------|----------|
| `student-info.txt` | Console URLs, API endpoints, bastion SSH, passwords for all clusters |
| `students.txt` | List of deployed GUIDs |

### Showroom Variable Naming

Student cluster data is available in the Antora lab content as attributes:

| Variable | Example |
|----------|---------|
| `{student_1_console_url}` | Console URL for student 1 |
| `{student_1_api_url}` | API URL for student 1 |
| `{student_1_bastion_hostname}` | Bastion hostname for student 1 |
| `{student_1_ssh_command}` | Full SSH command for student 1 |
| `{hub_console_url}` | Hub cluster console URL |
| `{hub_api_url}` | Hub cluster API URL |
| `{num_students}` | Total number of students deployed |
