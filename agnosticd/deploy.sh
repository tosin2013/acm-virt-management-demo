#!/usr/bin/env bash
# deploy.sh — ACM Virtual Machine Management Demo
#
# Deployment order:
#   1. Hub cluster (operators only, Showroom deferred)
#   2. Student clusters (with RHACM auto-import to hub)
#   3. Showroom on hub (with student cluster variables injected)
#   4. Generate student-info.txt
#
# Works with unmodified upstream agd — no -e flag needed.
# Runtime values are merged into generated vars files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGNOSTICD_ROOT="${AGNOSTICD_ROOT:-$HOME/Development/agnosticd-v2}"
VARS_DIR="$AGNOSTICD_ROOT/../agnosticd-v2-vars"
OUTPUT_DIR="$AGNOSTICD_ROOT/../agnosticd-v2-output"

BASE_GUID="${BASE_GUID:-acmvirt}"
HUB_CONFIG="${HUB_CONFIG:-acm-virt-hub}"
STUDENT_TYPE="${STUDENT_TYPE:-sno}"
if [[ "$STUDENT_TYPE" == "sno" ]]; then
  STUDENT_CONFIG_TEMPLATE="${STUDENT_CONFIG_TEMPLATE:-acm-virt-student-sno}"
else
  STUDENT_CONFIG_TEMPLATE="${STUDENT_CONFIG_TEMPLATE:-acm-virt-student}"
fi
ACCOUNT="${ACCOUNT:-sandbox3008}"
NUM_STUDENTS="${NUM_STUDENTS:-1}"
PARALLEL="${PARALLEL:-false}"
MANIFEST="$SCRIPT_DIR/students.txt"

DEPLOY_HUB="${DEPLOY_HUB:-true}"
DEPLOY_SHOWROOM="${DEPLOY_SHOWROOM:-true}"
HUB_GUID="${HUB_GUID:-${BASE_GUID}-hub}"

DEMO_ROOT="${DEMO_ROOT:-$HOME/acm-virt-management-demo}"

# -----------------------------------------------------------------
# Pre-flight: ensure vars symlinks exist so agd finds our configs
# -----------------------------------------------------------------
ensure_symlink() {
  local target="$1" link="$2"
  if [[ -L "$link" ]]; then
    return
  fi
  if [[ -f "$link" ]]; then
    echo "   Backing up $link -> ${link}.bak"
    mv "$link" "${link}.bak"
  fi
  ln -s "$target" "$link"
  echo "   Symlinked $link -> $target"
}

echo "==> Ensuring vars file symlinks (relative for container compatibility)..."
VARS_SUBDIR="$(basename "$SCRIPT_DIR")"
ensure_symlink "${VARS_SUBDIR}/acm-virt-hub.yaml" "$VARS_DIR/acm-virt-hub.yml"
ensure_symlink "${VARS_SUBDIR}/acm-virt-student.yaml" "$VARS_DIR/acm-virt-student.yml"
ensure_symlink "${VARS_SUBDIR}/acm-virt-student-sno.yaml" "$VARS_DIR/acm-virt-student-sno.yml"
echo ""

# -----------------------------------------------------------------
# Pre-flight: quota check
# -----------------------------------------------------------------
QUOTA_SCRIPT="$DEMO_ROOT/agnosticd/check-quota.sh"
if [[ -x "$QUOTA_SCRIPT" ]]; then
  echo "==> Running AWS quota pre-flight check..."
  if ! AWS_REGION="${AWS_REGION:-us-east-2}" NUM_STUDENTS="$NUM_STUDENTS" "$QUOTA_SCRIPT"; then
    echo ""
    echo "Quota check FAILED. Fix the issues above before deploying."
    echo "Override with SKIP_QUOTA_CHECK=true if you know what you're doing."
    if [[ "${SKIP_QUOTA_CHECK:-false}" != "true" ]]; then
      exit 1
    fi
    echo "SKIP_QUOTA_CHECK is set — proceeding anyway."
  fi
  echo ""
fi

# -----------------------------------------------------------------
# Pre-flight: pull secret
# -----------------------------------------------------------------
PULL_SECRET_FILE="${PULL_SECRET_FILE:-$HOME/pull-secret.json}"
SECRETS_FILE="$AGNOSTICD_ROOT/../agnosticd-v2-secrets/secrets.yml"

if [[ ! -f "$PULL_SECRET_FILE" ]]; then
  echo "ERROR: OpenShift pull secret not found at $PULL_SECRET_FILE"
  echo "Download it from https://console.redhat.com/openshift/downloads"
  exit 1
fi

if grep -q '<Add Your Pull Secret here>' "$SECRETS_FILE" 2>/dev/null; then
  echo "==> Populating ocp4_pull_secret from $PULL_SECRET_FILE ..."
  PULL_SECRET_CONTENT=$(cat "$PULL_SECRET_FILE")
  sed -i "s|ocp4_pull_secret: '.*'|ocp4_pull_secret: '${PULL_SECRET_CONTENT}'|" "$SECRETS_FILE"
  echo "   Pull secret injected into $SECRETS_FILE"
  echo ""
fi

# -----------------------------------------------------------------
# Step 1: Deploy hub cluster (skip Showroom — deployed after students)
# -----------------------------------------------------------------
cd "$AGNOSTICD_ROOT"
> "$MANIFEST"

if [[ "$DEPLOY_HUB" == "true" ]]; then
  echo "==> Deploying ACM Hub cluster ($HUB_GUID) ..."
  echo "   Showroom deferred until after student clusters are ready."
  ./bin/agd provision -g "$HUB_GUID" -c "$HUB_CONFIG" -a "$ACCOUNT"
  echo "$HUB_GUID" >> "$MANIFEST"
  echo "Hub cluster deployed (operators ready, Showroom pending)."
  echo ""
fi

# -----------------------------------------------------------------
# Extract hub credentials for student RHACM import
# -----------------------------------------------------------------
HUB_OUTPUT_DIR="$OUTPUT_DIR/$HUB_GUID"
HUB_USER_DATA="$HUB_OUTPUT_DIR/provision-user-data.yaml"

if [[ ! -f "$HUB_USER_DATA" ]]; then
  echo "ERROR: Hub user data not found at $HUB_USER_DATA"
  echo "The hub cluster must be deployed before student clusters."
  exit 1
fi

HUB_API_URL=$(grep 'openshift_api_url:' "$HUB_USER_DATA" | head -1 | awk '{print $2}')
HUB_TOKEN=$(grep 'openshift_cluster_admin_token:' "$HUB_USER_DATA" | head -1 | awk '{print $2}')
HUB_CONSOLE_URL=$(grep 'openshift_console_url:' "$HUB_USER_DATA" | head -1 | awk '{print $2}' || echo "N/A")
HUB_BASTION=$(grep 'bastion_public_hostname:' "$HUB_USER_DATA" | head -1 | awk '{print $2}' || echo "N/A")

echo "==> Hub credentials extracted for student RHACM import."
echo "   Hub API: $HUB_API_URL"
echo ""

# -----------------------------------------------------------------
# Step 2: Deploy student clusters
#   Generates a per-student vars file that merges the template
#   with runtime hub credentials. Works with unmodified agd.
# -----------------------------------------------------------------
deploy_student() {
  local guid="$1"
  local student_num="$2"
  local student_config="${STUDENT_CONFIG_TEMPLATE}-${student_num}"
  local template_file="$SCRIPT_DIR/${STUDENT_CONFIG_TEMPLATE}.yaml"

  {
    cat "$template_file"
    echo ""
    echo "# --- deploy.sh runtime: hub credentials for RHACM import ---"
    echo "ocp4_workload_rhacm_import_hub_api_url: \"$HUB_API_URL\""
    echo "ocp4_workload_rhacm_import_hub_token: \"$HUB_TOKEN\""
    echo "ocp4_workload_rhacm_import_cluster_name: \"student-${student_num}\""
  } > "$VARS_DIR/${student_config}.yml"

  echo "==> Deploying student cluster $student_num ($guid) ..."
  echo "$guid" >> "$MANIFEST"
  ./bin/agd provision -g "$guid" -c "$student_config" -a "$ACCOUNT"

  rm -f "$VARS_DIR/${student_config}.yml"
}

if (( NUM_STUDENTS > 0 )); then
  if [[ "$PARALLEL" == "true" ]]; then
    pids=()
    for i in $(seq 1 "$NUM_STUDENTS"); do
      deploy_student "${BASE_GUID}-s${i}" "$i" &
      pids+=($!)
    done
    for pid in "${pids[@]}"; do wait "$pid"; done
  else
    for i in $(seq 1 "$NUM_STUDENTS"); do
      deploy_student "${BASE_GUID}-s${i}" "$i"
    done
  fi
fi

# -----------------------------------------------------------------
# Step 3: Deploy Showroom on hub with student cluster data
#   Generates a hub vars file that appends student cluster details
#   as Showroom Antora attributes. Operators skip (idempotency).
# -----------------------------------------------------------------
if [[ "$DEPLOY_SHOWROOM" == "true" ]]; then
  SHOWROOM_CONFIG="acm-virt-hub-showroom"
  echo "==> Collecting student cluster data for Showroom..."

  # Extract Grafana URL from hub user data (set by ocp4_workload_rhacm_observability)
  GRAFANA_URL=$(grep 'grafana_url:' "$HUB_USER_DATA" 2>/dev/null | head -1 | awk '{print $2}' || echo "")

  {
    cat "$SCRIPT_DIR/acm-virt-hub.yaml"
    echo ""
    echo "# --- deploy.sh runtime: override workloads to Showroom only ---"
    echo "# Operators are already installed; only Showroom needs to run."
    echo "workloads:"
    echo "  - agnosticd.core_workloads.ocp4_workload_showroom"
    echo ""
    echo "# --- deploy.sh runtime: student cluster data for Showroom ---"
    echo "hub_console_url: \"$HUB_CONSOLE_URL\""
    echo "hub_api_url: \"$HUB_API_URL\""
    echo "hub_bastion_hostname: \"$HUB_BASTION\""
    echo "num_students: $NUM_STUDENTS"
    if [[ -n "$GRAFANA_URL" ]]; then
      echo "grafana_url: \"$GRAFANA_URL\""
    fi

    for i in $(seq 1 "$NUM_STUDENTS"); do
      s_guid="${BASE_GUID}-s${i}"
      s_data="$OUTPUT_DIR/$s_guid/provision-user-data.yaml"

      if [[ -f "$s_data" ]]; then
        s_console=$(grep 'openshift_console_url:' "$s_data" 2>/dev/null | head -1 | awk '{print $2}' || echo "N/A")
        s_api=$(grep 'openshift_api_url:' "$s_data" 2>/dev/null | head -1 | awk '{print $2}' || echo "N/A")
        s_bastion=$(grep 'bastion_public_hostname:' "$s_data" 2>/dev/null | head -1 | awk '{print $2}' || echo "N/A")
        s_bastion_pass=$(grep 'bastion_ssh_password:' "$s_data" 2>/dev/null | head -1 | awk '{print $2}' || echo "N/A")
        s_bastion_user=$(grep 'bastion_ssh_user_name:' "$s_data" 2>/dev/null | head -1 | awk '{print $2}' || echo "student")

        echo ""
        echo "student_${i}_console_url: \"$s_console\""
        echo "student_${i}_api_url: \"$s_api\""
        echo "student_${i}_bastion_hostname: \"$s_bastion\""
        echo "student_${i}_bastion_ssh_user: \"$s_bastion_user\""
        echo "student_${i}_bastion_ssh_password: \"$s_bastion_pass\""
        echo "student_${i}_ssh_command: \"ssh ${s_bastion_user}@${s_bastion}\""

        s_ingress=$(grep 'openshift_cluster_ingress_domain:' "$s_data" 2>/dev/null | head -1 | awk '{print $2}' || echo "N/A")
        echo "student_${i}_ingress_domain: \"$s_ingress\""
      fi
    done
  } > "$VARS_DIR/${SHOWROOM_CONFIG}.yml"

  echo "==> Deploying Showroom on hub with student cluster data..."
  ./bin/agd provision -g "$HUB_GUID" -c "$SHOWROOM_CONFIG" -a "$ACCOUNT"
  echo "Showroom deployed with student cluster variables."
  echo ""

  rm -f "$VARS_DIR/${SHOWROOM_CONFIG}.yml"
fi

# -----------------------------------------------------------------
# Step 4: Generate student-info.txt
# -----------------------------------------------------------------
extract_field() {
  local file="$1" key="$2" default="${3:-N/A}"
  grep "${key}:" "$file" 2>/dev/null | head -1 | awk '{print $2}' || echo "$default"
}

generate_student_info() {
  local info_file="$SCRIPT_DIR/student-info.txt"
  echo "==> Generating deployment info..."

  local hub_data="$OUTPUT_DIR/$HUB_GUID/provision-user-data.yaml"
  local hub_kubeadmin_file="$OUTPUT_DIR/$HUB_GUID/openshift-cluster_${HUB_GUID}_kubeadmin-password"
  local hub_console hub_api hub_bastion hub_bastion_pass hub_bastion_user hub_admin_pass hub_grafana hub_showroom hub_ingress

  if [[ -f "$hub_data" ]]; then
    hub_console=$(extract_field "$hub_data" openshift_console_url)
    hub_api=$(extract_field "$hub_data" openshift_api_url)
    hub_bastion=$(extract_field "$hub_data" bastion_public_hostname)
    hub_bastion_pass=$(extract_field "$hub_data" bastion_ssh_password)
    hub_bastion_user=$(extract_field "$hub_data" bastion_ssh_user_name student)
    hub_ingress=$(extract_field "$hub_data" openshift_cluster_ingress_domain)
    hub_showroom=$(extract_field "$hub_data" lab_ui_url)
    if [[ "$hub_showroom" == "N/A" ]]; then
      hub_showroom=$(extract_field "$hub_data" showroom_primary_view_url)
    fi
    hub_grafana="https://grafana-open-cluster-management-observability.${hub_ingress}"
  fi
  # Hub uses kubeadmin password file; htpasswd admin password may also exist
  if [[ -f "$hub_kubeadmin_file" ]]; then
    hub_admin_pass="$(cat "$hub_kubeadmin_file" 2>/dev/null)"
    hub_admin_user="kubeadmin"
  else
    hub_admin_pass=$(extract_field "$hub_data" openshift_cluster_admin_password)
    hub_admin_user="admin"
  fi

  {
    echo "================================================================"
    echo "  ACM Virtual Machine Management Demo — Deployment Info"
    echo "  Generated: $(date)"
    echo "================================================================"
    echo ""
    echo "================================================================"
    echo "  HUB CLUSTER ACCESS"
    echo "================================================================"
    echo "  Console:   $hub_console"
    echo "  API:       $hub_api"
    echo "  Admin:     ${hub_admin_user} / ${hub_admin_pass}"
    echo "  Bastion:   ssh ${hub_bastion_user}@${hub_bastion}  (password: ${hub_bastion_pass})"
    echo "  oc login:  oc login ${hub_api} -u ${hub_admin_user} -p ${hub_admin_pass}"
    echo "  Showroom:  $hub_showroom"
    echo "  Grafana:   $hub_grafana"
    echo ""

    for i in $(seq 1 "$NUM_STUDENTS"); do
      local s_guid="${BASE_GUID}-s${i}"
      local s_data="$OUTPUT_DIR/$s_guid/provision-user-data.yaml"

      echo "================================================================"
      echo "  STUDENT CLUSTER ${i}  ($s_guid)"
      echo "================================================================"

      if [[ -f "$s_data" ]]; then
        local s_console s_api s_bastion s_bastion_pass s_bastion_user s_admin_pass s_ingress
        s_console=$(extract_field "$s_data" openshift_console_url)
        s_api=$(extract_field "$s_data" openshift_api_url)
        s_bastion=$(extract_field "$s_data" bastion_public_hostname)
        s_bastion_pass=$(extract_field "$s_data" bastion_ssh_password)
        s_bastion_user=$(extract_field "$s_data" bastion_ssh_user_name student)
        s_admin_pass=$(extract_field "$s_data" openshift_cluster_admin_password)
        s_ingress=$(extract_field "$s_data" openshift_cluster_ingress_domain)

        echo "  Console:   $s_console"
        echo "  API:       $s_api"
        echo "  Admin:     admin / $s_admin_pass"
        echo "  Bastion:   ssh ${s_bastion_user}@${s_bastion}  (password: ${s_bastion_pass})"
        echo "  oc login:  oc login $s_api -u admin -p $s_admin_pass"
        echo "  File Srv:  https://httpd-server-httpd-server.${s_ingress}"
        echo "  Type:      SNO (m5zn.metal, bare-metal KVM)"
      else
        echo "  (no data found — cluster may not be deployed yet)"
      fi
      echo ""
    done

    echo "================================================================"
    echo "  QUICK REFERENCE"
    echo "================================================================"
    echo "  Hub oc login:   oc login $hub_api -u $hub_admin_user -p $hub_admin_pass"
    echo "  Showroom:       $hub_showroom"
    echo "  Grafana:        $hub_grafana"
    echo "  Student info:   $info_file"
    echo "  Manifest:       $MANIFEST"
    echo "================================================================"
  } | tee "$info_file"

  echo ""
  echo "Info saved to: $info_file"

  if [[ -d "$DEMO_ROOT" ]]; then
    cp "$info_file" "$DEMO_ROOT/student-info.txt"
    echo "Also copied to: $DEMO_ROOT/student-info.txt"
  fi
}

generate_student_info

echo ""
echo "================================================================"
echo "Deployment complete."
echo "  Hub:      ${HUB_GUID}"
echo "  Students: ${NUM_STUDENTS} (type: ${STUDENT_TYPE})"
echo "  GUIDs:    $(tr '\n' ' ' < "$MANIFEST")"
echo "  Info:     $SCRIPT_DIR/student-info.txt"
echo "================================================================"
