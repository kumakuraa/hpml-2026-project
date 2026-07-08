#!/usr/bin/env bash

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-aad-character-agent}"
ZONE="${ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-gemma-sft-gpu-1g}"
DATA_DISK_NAME="${DATA_DISK_NAME:-${VM_NAME}-data}"

usage() {
  cat <<'EOF'
Usage:
  PROJECT_ID=my-project \
  ZONE=us-central1-a \
  VM_NAME=gemma-sft-gpu-1g \
  infra/ubuntu/destroy_gpu_vm.sh

Optional environment variables:
  PROJECT_ID      GCP project ID
  ZONE            Compute Engine zone
  VM_NAME         VM name to delete
  DATA_DISK_NAME  Additional disk name to delete if it remains after VM deletion
  DRY_RUN         Set to 1 to print commands without executing them

Notes:
  - The boot disk is normally deleted automatically with the VM.
  - This script also tries to delete the extra data disk if it still exists.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud CLI is not installed or not in PATH." >&2
  exit 1
fi

delete_vm_cmd=(
  gcloud compute instances delete "$VM_NAME"
  --project="$PROJECT_ID"
  --zone="$ZONE"
  --quiet
)

delete_disk_cmd=(
  gcloud compute disks delete "$DATA_DISK_NAME"
  --project="$PROJECT_ID"
  --zone="$ZONE"
  --quiet
)

printf 'Prepared VM delete command:\n'
printf ' %q' "${delete_vm_cmd[@]}"
printf '\n'
printf 'Prepared data disk delete command:\n'
printf ' %q' "${delete_disk_cmd[@]}"
printf '\n'

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  exit 0
fi

"${delete_vm_cmd[@]}" || true

if gcloud compute disks describe "$DATA_DISK_NAME" \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  >/dev/null 2>&1; then
  "${delete_disk_cmd[@]}"
else
  echo "Data disk $DATA_DISK_NAME does not exist or was already auto-deleted."
fi