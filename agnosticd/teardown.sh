#!/usr/bin/env bash
# teardown.sh — ACM Virtual Machine Management Demo
set -euo pipefail

AGNOSTICD_ROOT="${AGNOSTICD_ROOT:-$HOME/Development/agnosticd-v2}"
ACCOUNT="${ACCOUNT:-sandbox3008}"
PARALLEL="${PARALLEL:-false}"
MANIFEST="$(dirname "$0")/students.txt"

[ -f "$MANIFEST" ] || { echo "No students.txt manifest found. Nothing to destroy."; exit 0; }

config_for_guid() {
  if [[ "$1" == *-s[0-9]* ]]; then
    if [[ "${STUDENT_TYPE:-sno}" == "sno" ]]; then
      echo "acm-virt-student-sno"
    else
      echo "acm-virt-student"
    fi
  else
    echo "acm-virt-hub"
  fi
}

echo "NOTE: If student clusters are registered to RHACM on the hub,"
echo "ensure they are detached before destroy — either manually (delete ManagedCluster)"
echo "or via your project's RHACM detach workload role in the destroy playbook."
echo ""
echo "GUIDs to destroy:"
cat "$MANIFEST"
echo ""
read -rp "Continue with teardown? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 0

cd "$AGNOSTICD_ROOT"

destroy_one() {
  local cfg
  cfg=$(config_for_guid "$1")
  ./bin/agd destroy -g "$1" -c "$cfg" -a "$ACCOUNT"
}

if [[ "$PARALLEL" == "true" ]]; then
  pids=()
  while IFS= read -r guid; do destroy_one "$guid" & pids+=($!); done < "$MANIFEST"
  for pid in "${pids[@]}"; do wait "$pid"; done
else
  while IFS= read -r guid; do destroy_one "$guid"; done < "$MANIFEST"
fi

rm -f "$MANIFEST"
echo "All environments destroyed."
