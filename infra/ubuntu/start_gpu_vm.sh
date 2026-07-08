#!/usr/bin/env bash

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-aad-character-agent}"
ZONE="${ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-gemma-sft-gpu-1g}"

usage() {
  cat <<'EOF'
Usage:
  PROJECT_ID=my-project \
  ZONE=us-central1-a \
  VM_NAME=gemma-sft-gpu-1g \
  infra/ubuntu/start_gpu_vm.sh

Optional environment variables:
  PROJECT_ID      GCP project ID
  ZONE            Compute Engine zone
  VM_NAME         VM name to start
  DRY_RUN         Set to 1 to print the command without executing it

Notes:
  - Starting a stopped GPU VM requires capacity in the same zone.
  - If the instance was originally created in a fallback zone, use that actual zone.
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

start_vm_cmd=(
  gcloud compute instances start "$VM_NAME"
  --project="$PROJECT_ID"
  --zone="$ZONE"
)

printf 'Prepared VM start command:\n'
printf ' %q' "${start_vm_cmd[@]}"
printf '\n'

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  exit 0
fi

"${start_vm_cmd[@]}"