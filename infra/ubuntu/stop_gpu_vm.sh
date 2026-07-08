#!/usr/bin/env bash

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-aad-character-agent}"
ZONE="${ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-gemma-sft-gpu-1g}"
DISCARD_LOCAL_SSD="${DISCARD_LOCAL_SSD:-true}"

usage() {
  cat <<'EOF'
Usage:
  PROJECT_ID=my-project \
  ZONE=us-central1-a \
  VM_NAME=gemma-sft-gpu-1g \
  infra/ubuntu/stop_gpu_vm.sh

Optional environment variables:
  PROJECT_ID      GCP project ID
  ZONE            Compute Engine zone
  VM_NAME         VM name to stop
  DISCARD_LOCAL_SSD
                  Required when the VM has Local SSD attached.
                  Set to true to stop the VM and discard Local SSD data.
  DRY_RUN         Set to 1 to print the command without executing it

Notes:
  - Stopping the VM preserves attached persistent disks and instance metadata.
  - GPU, vCPU, and memory charges stop while the instance is stopped.
  - Persistent disk charges continue until the disks are deleted.
  - Local SSD data is ephemeral; the default is DISCARD_LOCAL_SSD=true.
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

stop_vm_cmd=(
  gcloud compute instances stop "$VM_NAME"
  --project="$PROJECT_ID"
  --zone="$ZONE"
  --discard-local-ssd="$DISCARD_LOCAL_SSD"
)

printf 'Prepared VM stop command:\n'
printf ' %q' "${stop_vm_cmd[@]}"
printf '\n'

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  exit 0
fi

"${stop_vm_cmd[@]}"