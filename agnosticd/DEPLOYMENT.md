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

## Clone This Repository

Clone the workshop repo **inside** the `agnosticd-v2-vars/` directory so `deploy.sh`
can correctly create symlinks to the vars files:

```bash
cd ~/Development/agnosticd-v2-vars
git clone https://github.com/tosin2013/acm-virt-management-demo.git
```

Your directory structure should look like:

```
~/Development/
├── agnosticd-v2/                  # AgnosticD CLI
├── agnosticd-v2-vars/
│   ├── acm-virt-management-demo/  # ← this repo (cloned here)
│   │   ├── agnosticd/
│   │   │   ├── acm-virt-hub.yaml
│   │   │   ├── acm-virt-student-sno.yaml
│   │   │   └── deploy.sh
│   │   └── ...
│   ├── acm-virt-hub.yml           # ← symlink (created by deploy.sh)
│   ├── acm-virt-student-sno.yml   # ← symlink (created by deploy.sh)
│   └── acm-virt-student.yml       # ← symlink (created by deploy.sh)
├── agnosticd-v2-secrets/
└── agnosticd-v2-output/
```

> **Important:** `deploy.sh` automatically creates the `.yml` symlinks pointing to
> the `.yaml` files inside the repo. If the symlinks are broken (e.g., `cat` returns
> "No such file or directory"), delete them and re-run `deploy.sh` — it will recreate
> them with the correct relative path.

## Secrets Configuration

Create a secrets file named to match your **ACCOUNT** value. The `ACCOUNT` environment
variable (default: `sandbox3008`) tells `agd` which secrets file to read. The filename
must follow the pattern `secrets-<ACCOUNT>.yml`.

```bash
cd ~/Development/agnosticd-v2-secrets

# If using the default ACCOUNT=sandbox3008:
cp secrets-example.yml secrets-sandbox3008.yml

# If using your own account name (e.g., ACCOUNT=mylab):
cp secrets-example.yml secrets-mylab.yml
```

Fill in **your own environment's** values:

```yaml
aws_access_key_id: "AKIA..."
aws_secret_access_key: "wJalr..."
base_domain: "sandbox3008.opentlc.com"   # ← replace with YOUR base domain
```

> **Important:** The `ACCOUNT` variable in `deploy.sh` and the secrets filename must
> match. If you set `ACCOUNT=mylab`, the secrets file must be `secrets-mylab.yml` and
> `base_domain` must be your actual domain (e.g., `mylab.example.com`).

## Pre-Deployment Checklist

Before running `deploy.sh`, verify ALL of the following:

### 1. Route53 Hosted Zone Exists

The OpenShift installer **requires** a Route53 hosted zone matching your `base_domain`.
Without it, the installer will hang indefinitely (8+ hours) trying to validate DNS.

```bash
# Verify your hosted zone exists
aws route53 list-hosted-zones --query "HostedZones[?Name=='sandbox3008.opentlc.com.'].Id"
```

If empty, create one or ensure your `base_domain` value matches an existing hosted zone.

### 2. Pull Secret is Valid

```bash
# Verify pull secret exists and is valid JSON
cat ~/pull-secret.json | python3 -m json.tool > /dev/null && echo "OK" || echo "INVALID"

# Check expiry (Red Hat pull secrets expire periodically)
# Re-download from https://console.redhat.com/openshift/install/pull-secret if needed
```

### 3. IAM Permissions

The AWS credentials in your secrets file need **full permissions** for:
EC2, VPC, Route53, ELB/NLB, IAM (instance profiles), S3, and CloudFormation.

```bash
# Quick sanity check — this must succeed
aws sts get-caller-identity
aws ec2 describe-instance-types --instance-types m5.xlarge --query 'InstanceTypes[0].InstanceType'
```

### 4. Customize `acm-virt-hub.yaml` (Optional but Recommended)

The vars file has some values you should change for your own deployment:

| Line | Setting | Default | Change to |
|------|---------|---------|-----------|
| 33 | `owner` tag | `takinosh@redhat.com` | Your email |
| 42 | `host_ssh_authorized_keys` | `https://github.com/tosin2013.keys` | Your GitHub keys URL or local key |
| 30 | `aws_region` | `us-east-2` | Your preferred region (must have m5.xlarge + m5zn.metal) |

These are optional — the deployment will work without changing them — but the `owner`
tag helps identify resources in a shared AWS account, and the SSH key controls who can
access the bastion.

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
./agnosticd/deploy.sh
```

#### Environment Variables

All variables have sensible defaults — you only need to set them if your environment
differs from the defaults. Export them before running `deploy.sh` or pass inline:

```bash
# Example: custom account with 2 students
ACCOUNT=mylab NUM_STUDENTS=2 ./agnosticd/deploy.sh
```

| Variable | Default | Description | When to change |
|----------|---------|-------------|----------------|
| `NUM_STUDENTS` | `1` | Number of student clusters | Multi-student workshops |
| `STUDENT_TYPE` | `sno` | `sno` or `multinode` | Need HA/live migration |
| `PARALLEL` | `false` | Parallel student provisioning | >2 students |
| `DEPLOY_HUB` | `true` | Deploy the RHACM hub cluster | Set `false` if hub already exists |
| `DEPLOY_SHOWROOM` | `true` | Deploy Showroom after students | Set `false` to skip lab guide |
| `HUB_GUID` | `acmvirt-hub` | GUID for the hub cluster | Must be unique per deployment |
| `ACCOUNT` | `sandbox3008` | AgnosticD account name (matches secrets filename) | **Always set to your account** |
| `SKIP_QUOTA_CHECK` | `false` | Bypass quota pre-flight | Only if you've verified manually |

> **Critical:** If you are NOT using the `sandbox3008` account, you **must** set
> `ACCOUNT` to match your secrets file. For example, if your secrets file is
> `secrets-mylab.yml`, run: `ACCOUNT=mylab ./agnosticd/deploy.sh`

### Cost-Optimized: SNO Students (Default)

By default, student clusters deploy as Single Node OpenShift (SNO) on `m5zn.metal`
(48 vCPU, 192 GiB RAM, ~$3.96/hr). This is the cheapest AWS option that provides
bare-metal KVM support for OpenShift Virtualization.

```bash
# Default — SNO students
./agnosticd/deploy.sh

# Explicit
STUDENT_TYPE=sno ./agnosticd/deploy.sh
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
STUDENT_TYPE=multinode ./agnosticd/deploy.sh
```

This deploys students with 3x m5.metal workers (same as hub). Requires 604+ vCPUs
of AWS quota — request an increase before deploying.

### Hub-only Deployment

```bash
NUM_STUDENTS=0 ./agnosticd/deploy.sh
```

### Re-running After a Partial Failure

Simply re-run `./agnosticd/deploy.sh`. Already-installed operators are detected and skipped
automatically. The script picks up where it left off.

```bash
# Skip hub if already deployed
DEPLOY_HUB=false ./agnosticd/deploy.sh
```

### Monitoring Logs

```bash
tail -f ~/Development/agnosticd-v2-output/acmvirt-hub/acmvirt-hub.log
```

### Stop / Start / Status

```bash
./agnosticd/stop.sh      # stop all clusters (cost savings)
./agnosticd/start.sh     # restart stopped clusters
```

### Teardown

```bash
./agnosticd/teardown.sh  # destroy all clusters (confirms before proceeding)
```

## Troubleshooting

### OpenShift Installer Timeout (host_ocp4_installer fails after 99 retries)

**Symptoms:**
```
[ERROR]: Task failed: Module failed: The command exited with a non-zero return code.
Origin: .../ansible/roles/host_ocp4_installer/tasks/main.yml:34:7
    - name: Check installer status
fatal: ... "attempts": 99, "delta": "8:26:55.827564" ...
stderr: level=info msg=Consuming Worker Machines from target directory
```

The OpenShift installer ran for 8+ hours and never completed bootstrap. The cluster
nodes did not come online.

**Most common causes:**

| Cause | How to verify | Fix |
|-------|---------------|-----|
| **AWS vCPU quota insufficient** | Run `./agnosticd/check-quota.sh` | Request quota increase in [AWS Service Quotas](https://console.aws.amazon.com/servicequotas/) |
| **Instance type unavailable in AZ** | Check AWS console → EC2 → Instance Types → filter by `m5.metal` | Change `AWS_REGION` or use a different AZ |
| **Base domain DNS not configured** | `dig +short NS yourdomain.com` should return AWS nameservers | Ensure Route53 hosted zone exists and matches `base_domain` |
| **VPC / EIP / NAT Gateway limit** | AWS console → VPC → check counts | Delete unused VPCs or request limit increase |
| **Expired or invalid AWS credentials** | `aws sts get-caller-identity` | Refresh credentials in secrets file |

**Debugging steps:**

1. Check the installer log:
   ```bash
   cat ~/Development/agnosticd-v2-output/<GUID>/.openshift_install.log | tail -50
   ```

2. Check AWS CloudFormation stacks (IPI creates stacks):
   ```bash
   aws cloudformation list-stacks --region us-east-2 --stack-status-filter CREATE_IN_PROGRESS CREATE_FAILED
   ```

3. If instances were created but never bootstrapped, check EC2 console for instances
   in `running` state with the cluster's `InfraID` tag — they may be running but
   unreachable due to security group or DNS issues.

**Recovery:** After fixing the root cause, teardown the failed attempt and re-deploy:
```bash
./agnosticd/teardown.sh
./agnosticd/deploy.sh
```

### Execution Environment Image Pull Failure

If `deploy.sh` fails with an error like:

```
Error: unable to copy from source docker://quay.io/agnosticd/ee-multicloud:chained-YYYY-MM-DD
Tag chained-YYYY-MM-DD was deleted or has expired
```

The `chained-*` execution environment (EE) image tags are built on-demand -- not
daily. Your `ansible-navigator.yml` may reference a tag that doesn't exist yet.

**Fix:** Edit `~/Development/agnosticd-v2/ansible-navigator.yml` and change the
image tag to a known good value:

```yaml
ansible-navigator:
  execution-environment:
    container-engine: podman
    image: quay.io/agnosticd/ee-multicloud:chained-latest   # always available
    pull:
      policy: missing
```

Alternatively, list available tags and pick the most recent one:

```bash
podman search --list-tags quay.io/agnosticd/ee-multicloud | grep chained | sort
```

## Architecture

### Hub Cluster (`acm-virt-hub.yaml`)

| Component | Purpose |
|-----------|---------|
| RHACM 2.17 | Multicluster governance (VM right-sizing, fine-grained RBAC, cross-cluster live migration) |
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
| `{hub_ssh_command}` | Full SSH command for Hub bastion |
| `{grafana_url}` | RHACM Observability Grafana URL |
| `{num_students}` | Total number of students deployed |
