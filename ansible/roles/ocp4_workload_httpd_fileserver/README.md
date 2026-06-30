# ocp4_workload_httpd_fileserver

AgnosticD workload role that deploys an HTTP file server on OpenShift for
hosting ISO images and large files consumed by CDI DataVolumes and Tekton
pipelines.

## What Gets Deployed

| Resource | Name | Purpose |
|----------|------|---------|
| Namespace | `httpd-server` | Dedicated namespace for all resources |
| ServiceAccount | `httpd-fileserver` | OAuth redirect annotation for the proxy |
| PersistentVolumeClaim | `httpd-server-data` | File storage (100Gi gp3-csi, RWO) |
| ImageStream | `httpd-fileserver` | Tracks built images |
| BuildConfig | `httpd-fileserver` | Builds the Go binary from Git source |
| Deployment | `httpd-fileserver` | Two containers: oauth-proxy + file server |
| Service | `httpd-server` | Dual-port: 8080 (direct) and 443 (OAuth proxy) |
| Route | `httpd-server` | Reencrypt TLS termination to OAuth proxy |
| Secret (auto) | `httpd-fileserver-proxy-tls` | Auto-generated serving cert via annotation |

## Authentication Model

External access through the Route is protected by an **OpenShift OAuth Proxy**
sidecar (`ose-oauth-proxy-rhel9`). The proxy handles the full OAuth2 flow
against the cluster's identity providers.

### Important: Identity Provider Considerations

- **htpasswd clusters (AgnosticD default):** The `kubeadmin` user does **not**
  work for browser-based OAuth login if the `kubeadmin` secret was removed from
  `kube-system` (standard AgnosticD behavior). Users must log in with htpasswd
  users (e.g., `admin`, `user1`–`user5`).

- **kubeadmin vs. oc login:** The `kubeadmin` credentials may still work with
  `oc login` (API-level auth) even when the kube:admin identity provider is
  gone. This only affects the browser OAuth flow.

- **Password sync:** If the htpasswd `admin` password differs from the
  `kubeadmin` password in your student-info file, you can update it. See the
  [component README](../../components/httpd-fileserver/README.md) for
  instructions.

### Internal Access (No Auth)

The Service exposes port 8080 targeting the app directly, bypassing the OAuth
proxy. In-cluster consumers (CDI DataVolumes, Tekton tasks) use:

```
http://httpd-server.httpd-server.svc.cluster.local:8080/files/<filename>
```

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ocp4_workload_httpd_fileserver_namespace` | `httpd-server` | Target namespace |
| `ocp4_workload_httpd_fileserver_pvc_size` | `100Gi` | PVC storage size |
| `ocp4_workload_httpd_fileserver_storage_class` | `gp3-csi` | StorageClass for the PVC |
| `ocp4_workload_httpd_fileserver_service_name` | `httpd-server` | Service and Route name |
| `ocp4_workload_httpd_fileserver_route_timeout` | `600s` | HAProxy route timeout (for large uploads) |
| `ocp4_workload_httpd_fileserver_source_repo` | `https://github.com/tosin2013/acm-virt-management-demo.git` | Git repo for BuildConfig |
| `ocp4_workload_httpd_fileserver_source_ref` | `main` | Git branch/ref |
| `ocp4_workload_httpd_fileserver_source_context` | `components/httpd-fileserver` | Build context path in the repo |
| `ocp4_workload_httpd_fileserver_cookie_secret` | (auto-generated) | Base64-encoded random string for OAuth proxy cookie encryption |

## AgnosticD User Data

The role registers these values via `agnosticd_user_info`:

| Key | Example | Description |
|-----|---------|-------------|
| `httpd_fileserver_route_url` | `https://httpd-server-httpd-server.apps.cluster.example.com` | External URL (OAuth-protected) |
| `httpd_fileserver_internal_url` | `http://httpd-server.httpd-server.svc.cluster.local` | Internal URL (no auth) |

## Usage

Add to your AgnosticD config:

```yaml
ocp4_workload_list:
  - ocp4_workload_httpd_fileserver
```

Override variables as needed:

```yaml
ocp4_workload_httpd_fileserver_pvc_size: 200Gi
ocp4_workload_httpd_fileserver_storage_class: ocs-storagecluster-ceph-rbd
```

## Removal

The `remove_workload.yml` playbook cleans up all resources in reverse order,
including the namespace and PVC (data will be lost).
