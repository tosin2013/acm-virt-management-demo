# HTTP File Server

A lightweight Go-based file server for hosting ISO images and other large files
inside an OpenShift cluster. It provides a drag-and-drop web UI for uploading
files and serves them over HTTP for consumption by CDI DataVolumes, Tekton
pipelines, and other in-cluster workloads.

## Authentication

External access (via the OpenShift Route) is protected by an **OpenShift OAuth
Proxy** sidecar. Users must log in with their OpenShift credentials through the
standard OAuth flow before they can reach the UI.

**Which credentials work?** Any user registered with the cluster's identity
providers. If the cluster uses `htpasswd` authentication (the default for
AgnosticD deployments), the valid users are those in the htpasswd secret — 
typically `admin` and `user1`–`user5`. The `kubeadmin` user does **not** work
for OAuth web login if the `kubeadmin` secret has been removed from
`kube-system` (standard AgnosticD behavior when htpasswd auth is configured).

> **Tip:** If you only see `kubeadmin` in your student-info file, you can reset
> the `admin` htpasswd password to the kubeadmin password so the same
> credentials work everywhere:
>
> ```bash
> PASS="<kubeadmin-password>"
> HTPASSWD=$(oc get secret htpasswd -n openshift-config -o jsonpath='{.data.htpasswd}' | base64 -d)
> NEW=$(htpasswd -nbB admin "$PASS")
> echo "$HTPASSWD" | sed "s|^admin:.*|$NEW|" | \
>   oc create secret generic htpasswd --from-file=htpasswd=/dev/stdin \
>   -n openshift-config --dry-run=client -o yaml | oc apply -f -
> ```

**Internal (in-cluster) access is unauthenticated.** The Service exposes port
8080 (direct to app) for workloads that need to pull files without OAuth, such
as CDI DataVolume imports.

## Access Patterns

| Consumer | URL | Auth |
|----------|-----|------|
| Browser (upload UI) | `https://<route>/` | OpenShift OAuth (login required) |
| In-cluster workload | `http://httpd-server.httpd-server.svc.cluster.local:8080/files/<name>` | None |
| API (external) | `https://<route>/api/files` | OAuth session cookie |
| Health check | `http://localhost:8080/healthz` | None |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Web UI (drag-and-drop upload interface) |
| `GET` | `/healthz` | Liveness/readiness probe |
| `GET` | `/api/files` | List uploaded files as JSON |
| `POST` | `/api/upload` | Upload a file (multipart/form-data, field name: `file`) |
| `DELETE` | `/api/delete/<filename>` | Delete a file |
| `GET` | `/files/<filename>` | Download/serve a file |

## Architecture

```
                    ┌─────────────────────────────────────────────┐
  Browser ──HTTPS──▶│  Route (reencrypt TLS)                      │
                    │    ↓                                        │
                    │  oauth-proxy :8443  ──────▶  app :8080      │
                    │  (OpenShift OAuth)          (Go file server) │
                    └─────────────────────────────────────────────┘
                    ┌─────────────────────────────────────────────┐
  In-cluster ──HTTP▶│  Service port 8080 ──────▶  app :8080        │
  (DataVolumes,     │  (no auth)                                  │
   Pipelines)       └─────────────────────────────────────────────┘
```

## Building

The image is built automatically via an OpenShift `BuildConfig` from the Git
source. To build locally:

```bash
podman build -t httpd-fileserver -f Containerfile .
```

## Windows Image Pipeline

The `pipelines/` directory contains Tekton resources for building Windows
Server 2019 VM disk images:

| File | Purpose |
|------|---------|
| `windows-image-pipeline.yaml` | Pipeline + Task definitions |
| `windows-image-pipelinerun.yaml` | PipelineRun to trigger a build |
| `windows-iso-datavolume.yaml` | Standalone DataVolume for ISO import |
| `windows-disk-datavolume.yaml` | Standalone DataVolume for blank install disk |

**Workflow:**

1. Upload the Windows ISO to the file server UI as `win2k19.iso`
2. The pipeline creates a CDI DataVolume that imports the ISO from
   `http://httpd-server.httpd-server.svc.cluster.local:8080/files/win2k19.iso`
3. A blank disk DataVolume is provisioned for installation
4. A VM boots from the ISO with VirtIO drivers attached for installation

## Configuration

The application reads these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Listen port for the HTTP server |
| `SERVICE_URL` | auto-detected | Base URL for file download links in API responses (set to the in-cluster Service URL by the Deployment) |

File storage is at `/data` inside the container, backed by a PVC.
