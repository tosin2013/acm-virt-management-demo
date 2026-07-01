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

### Minimum Quotas (default: 1 hub with m5.metal + 1 SNO student on m5zn.metal)

| Resource | Hub (m5.metal) | Student (SNO) | Total (2) | Default Quota | Action |
|----------|----------------|---------------|-----------|---------------|--------|
| On-Demand vCPUs | 302 | 50 | 352 | 528 | OK |
| Elastic IPs | 2 | 2 | 4 | 5 | OK (increase if adding students) |
| VPCs | 1 | 1 | 2 | 5 | OK |
| NAT Gateways | 1 | 1 | 2 | 5 | OK |
| NLBs | 2 | 2 | 4 | 50 | OK |

To request increases: [AWS Service Quotas Console](https://console.aws.amazon.com/servicequotas/)

> **Note:** The default SNO deployment (1 hub + 1 student) requires only **352 vCPUs**,
> which fits within the default AWS quota of 528. For multi-node students
> (`STUDENT_TYPE=multinode`), 604+ vCPUs are needed — request a quota increase first.

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
| `STUDENT_TYPE` | `sno` | Student cluster topology: `sno` (single bare-metal node) or `multinode` (3 masters + 3 workers) |
| `PARALLEL` | `false` | Parallel student provisioning |
| `DEPLOY_HUB` | `true` | Deploy the RHACM hub cluster |
| `DEPLOY_SHOWROOM` | `true` | Deploy Showroom after students (with their data) |
| `HUB_GUID` | `acmvirt-hub` | GUID for the hub cluster |
| `ACCOUNT` | `sandbox3008` | AgnosticD account name |
| `SKIP_QUOTA_CHECK` | `false` | Bypass quota pre-flight |

### Cost-Optimized: SNO Students (Default)

By default, student clusters deploy as Single Node OpenShift (SNO) on `m5zn.metal`
(48 vCPU, 192 GiB RAM, ~$3.96/hr). This is the cheapest AWS option that provides
bare-metal KVM support for OpenShift Virtualization.

```bash
# Default — SNO students
./deploy.sh

# Explicit
STUDENT_TYPE=sno ./deploy.sh
```

**Quota requirements (1 hub + 1 SNO student):**

| Resource | Hub (m5.metal) | Student (SNO m5zn.metal) | Total | Default Quota |
|----------|----------------|--------------------------|-------|---------------|
| On-Demand vCPUs | 302 | 50 | 352 | 528 — OK |
| Elastic IPs | 2 | 2 | 4 | 5 — OK |
| VPCs | 1 | 1 | 2 | 5 — OK |

**Tradeoffs vs. multi-node:**

- No live migration (single node)
- No HA — if the node dies, everything is down
- Control plane and VMs share the same 48 vCPU / 192 GiB
- Perfectly acceptable for demos and workshops

### Full Multi-Node Students

For production-like environments or when live migration testing is needed:

```bash
STUDENT_TYPE=multinode ./deploy.sh
```

This deploys students with 3x m5.metal workers (same as hub). Requires 604+ vCPUs
of AWS quota — request an increase before deploying.

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
| RHACM Observability | Centralized Grafana + Thanos with auto-provisioned S3 bucket |
| OpenShift GitOps | ArgoCD for declarative VM deployment (ApplicationSet controller enabled) |
| OADP | Velero-based VM backup |
| cert-manager | TLS certificate automation |
| Showroom | Interactive demo lab guide |

Worker nodes use `m5.xlarge` instance type (standard compute — VMs run on student clusters).

### Student Clusters (`acm-virt-student-sno.yaml` / `acm-virt-student.yaml`)

| Component | Purpose |
|-----------|---------|
| OpenShift Virtualization | KVM-based VM hosting (Fedora and Windows VMs) |
| HTTP File Server | In-cluster file server for Windows ISO hosting |
| cert-manager | TLS certificate automation |
| htpasswd auth | Student user accounts |
| RHACM Import | Auto-registers spoke with hub RHACM |
| application-manager addon | Provides credentials for ArgoCD cluster registration |

**SNO (default):** Single `m5zn.metal` node (48 vCPU, 192 GiB) — runs control plane
and workloads on one bare-metal instance with KVM support.

**Multi-node:** 3x `m5.metal` workers (same as hub) — full HA with live migration support.

### Custom Roles

| Role | Location | Purpose |
|------|----------|---------|
| `ocp4_workload_oadp` | `ansible/roles/ocp4_workload_oadp/` | Installs OADP operator with idempotency |
| `ocp4_workload_rhacm_import` | `ansible/roles/ocp4_workload_rhacm_import/` | Imports spoke cluster into RHACM hub with configurable labels |
| `ocp4_workload_rhacm_observability` | `ansible/roles/ocp4_workload_rhacm_observability/` | Deploys MCO with S3-backed Thanos and Grafana |
| `install_operator` (modified) | `ansible/roles/install_operator/` | Added CSV pre-check for idempotent installs |

## Output Files

After deployment, find these in the vars directory:

| File | Contents |
|------|----------|
| `student-info.txt` | Console URLs, API endpoints, bastion SSH, passwords for all clusters |
| `students.txt` | List of deployed GUIDs |

## Post-Deployment: Upload Windows ISO

After all clusters are provisioned and the HTTP file server is running on the student
cluster, admins **must** upload the Windows Server 2019 ISO before students can complete
Module 1 Part 3 (Windows VM deployment via GitOps).

### Steps

1. Open the file server UI in your browser:
   ```
   https://httpd-server-httpd-server.apps.student.<STUDENT-GUID>.sandbox.opentlc.com
   ```

2. Log in with the student cluster's OpenShift OAuth credentials (e.g., `admin` user)

3. Upload the Windows Server 2019 ISO using the drag-and-drop interface. **Name the file `win2k19.iso`.**

4. Verify the upload using the validation script (run from the student bastion):
   ```bash
   # From the student bastion (SSH in first)
   /tmp/validate-iso.sh
   ```

   Or check manually:
   ```bash
   oc exec -n httpd-server deploy/httpd-fileserver -c httpd-fileserver -- stat -c '%s' /data/win2k19.iso
   ```

### Why This Is Manual

The Windows ISO is ~5.3 GB and cannot be redistributed in Git or container images due
to Microsoft licensing. It must be uploaded once per deployment. The DataVolume in
`examples/vm-win2019/datavolume-iso.yaml` references the internal service URL
(`http://httpd-server.httpd-server.svc.cluster.local:8080/files/win2k19.iso`), so the
ISO must be present before the Windows VM ArgoCD Application can sync successfully.

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
| `{grafana_url}` | RHACM Observability Grafana URL |
| `{num_students}` | Total number of students deployed |
