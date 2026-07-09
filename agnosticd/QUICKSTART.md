# Quick Start

Deploy the ACM + OpenShift Virtualization workshop in 5 steps.

**You need:** An AWS account with Route53 hosted zone, and an
[OpenShift pull secret](https://console.redhat.com/openshift/downloads).

## 1. Clone the repo

```bash
git clone https://github.com/tosin2013/acm-virt-management-demo.git
cd acm-virt-management-demo
```

## 2. Run the setup wizard

**Option A — Terminal (no AI required):**

```bash
make setup
# or: ./bootstrap.sh
```

**Option B — AI-assisted (Cursor or Claude Code):**

```
/onboard
```

Both paths install prerequisites (Python, Podman, AWS CLI, sshpass),
clone AgnosticD v2, and walk you through configuration. Supports
macOS, RHEL 8/9/10, Fedora, CentOS Stream, Debian, and Ubuntu.

> **Contributors:** Use `make setup-dev` to also install linters
> (shellcheck, yamllint).

## 3. Fill in AWS credentials

The wizard tells you which secrets file to edit. Add your AWS keys
and base domain:

```yaml
aws_access_key_id: "AKIA..."
aws_secret_access_key: "wJalr..."
base_domain: "yourdomain.example.com"
```

## 4. Deploy

```bash
make deploy
```

This provisions the hub cluster, student clusters, registers them
with RHACM, and deploys Showroom. Takes 1-2 hours.

## 5. Tear down

```bash
make teardown
```

---

**Useful commands:**

| Command | Description |
|---------|-------------|
| `make setup` | Interactive setup wizard |
| `make setup-dev` | Dev setup (includes linters) |
| `make deploy` | Deploy hub + student clusters |
| `make teardown` | Destroy all clusters |
| `make check-ready` | Validate readiness without deploying |

Need more control? Override any setting with env vars:

```bash
NUM_STUDENTS=3 STUDENT_TYPE=multinode make deploy
```

Full reference: [DEPLOYMENT.md](DEPLOYMENT.md)
