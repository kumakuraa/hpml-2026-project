#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_ID="${PROJECT_ID:-aad-character-agent}"
ZONE="${ZONE:-us-central1-a}"
FALLBACK_ZONES="${FALLBACK_ZONES:-}"
VM_NAME="${VM_NAME:-gemma-sft-gpu-1g}"
MACHINE_TYPE="${MACHINE_TYPE:-a2-highgpu-1g}"
IMAGE_FAMILY="${IMAGE_FAMILY:-common-cu129-ubuntu-2404-nvidia-580}"
IMAGE_NAME="${IMAGE_NAME:-}"
IMAGE_PROJECT="${IMAGE_PROJECT:-deeplearning-platform-release}"
BOOT_DISK_SIZE="${BOOT_DISK_SIZE:-200GB}"
BOOT_DISK_TYPE="${BOOT_DISK_TYPE:-pd-ssd}"
DATA_DISK_SIZE="${DATA_DISK_SIZE:-500GB}"
SCOPES="${SCOPES:-https://www.googleapis.com/auth/cloud-platform}"
METADATA="${METADATA:-install-nvidia-driver=True}"
STARTUP_SCRIPT_FILE="${STARTUP_SCRIPT_FILE:-$SCRIPT_DIR/startup_hpml_2026.sh}"

usage() {
  cat <<'EOF'
Usage:
  PROJECT_ID=my-project \
  ZONE=us-central1-a \
  VM_NAME=gemma-sft-gpu-1g \
  MACHINE_TYPE=a2-highgpu-1g \
  infra/ubuntu/create_gpu_vm.sh

Optional environment variables:
  PROJECT_ID      GCP project ID
  ZONE            Compute Engine zone
  FALLBACK_ZONES  Comma-separated backup zones to try on capacity exhaustion
  VM_NAME         VM name
  MACHINE_TYPE    Accelerator-optimized machine type
                  Examples: a2-highgpu-1g, a2-ultragpu-1g
  IMAGE_FAMILY    Boot image family (default: common-cu129-ubuntu-2404-nvidia-580)
  IMAGE_NAME      Exact boot image name; if set, IMAGE_FAMILY is ignored
  IMAGE_PROJECT   Boot image project
  BOOT_DISK_SIZE  Boot disk size (default: 200GB)
  BOOT_DISK_TYPE  Boot disk type (default: pd-ssd)
  DATA_DISK_SIZE  Additional data disk size (default: 500GB)
  SCOPES          OAuth scopes
  METADATA        Instance metadata
  STARTUP_SCRIPT_FILE
                  Startup script to run on first boot; set to empty to skip
  DRY_RUN         Set to 1 to print the gcloud command without executing it

Prerequisites:
  - gcloud CLI is installed and initialized
  - compute.googleapis.com is enabled on the project
  - Your account can create Compute Engine instances
  - The target zone has quota and capacity for the chosen MACHINE_TYPE
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

metadata_from_file_args=()
if [[ -n "$STARTUP_SCRIPT_FILE" ]]; then
  if [[ ! -f "$STARTUP_SCRIPT_FILE" ]]; then
    echo "Startup script file not found: $STARTUP_SCRIPT_FILE" >&2
    exit 1
  fi
  metadata_from_file_args+=(--metadata-from-file="startup-script=$STARTUP_SCRIPT_FILE")
fi

build_gcloud_cmd() {
  local zone="$1"

  gcloud_cmd=(
    gcloud compute instances create "$VM_NAME"
    --project="$PROJECT_ID"
    --zone="$zone"
    --machine-type="$MACHINE_TYPE"
    --maintenance-policy=TERMINATE
    --image-project="$IMAGE_PROJECT"
    --boot-disk-size="$BOOT_DISK_SIZE"
    --boot-disk-type="$BOOT_DISK_TYPE"
    --create-disk="name=${VM_NAME}-data,size=${DATA_DISK_SIZE},type=pd-ssd,auto-delete=yes"
    --metadata="$METADATA"
    "${metadata_from_file_args[@]}"
    --scopes="$SCOPES"
  )

  if [[ -n "$IMAGE_NAME" ]]; then
    gcloud_cmd+=(--image="$IMAGE_NAME")
  else
    gcloud_cmd+=(--image-family="$IMAGE_FAMILY")
  fi
}

zones_to_try=("$ZONE")
if [[ -n "$FALLBACK_ZONES" ]]; then
  IFS=',' read -r -a fallback_zone_list <<< "$FALLBACK_ZONES"
  for fallback_zone in "${fallback_zone_list[@]}"; do
    fallback_zone="${fallback_zone//[[:space:]]/}"
    if [[ -n "$fallback_zone" && "$fallback_zone" != "$ZONE" ]]; then
      zones_to_try+=("$fallback_zone")
    fi
  done
fi

total_zones=${#zones_to_try[@]}
current_try=0

for zone_to_try in "${zones_to_try[@]}"; do
  current_try=$((current_try + 1))
  build_gcloud_cmd "$zone_to_try"

  printf 'Prepared command:\n'
  printf ' %q' "${gcloud_cmd[@]}"
  printf '\n'

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    continue
  fi

  if output=$("${gcloud_cmd[@]}" 2>&1); then
    printf '%s\n' "$output"
    exit 0
  fi

  printf '%s\n' "$output" >&2

  if [[ "$output" == *"ZONE_RESOURCE_POOL_EXHAUSTED_WITH_DETAILS"* || "$output" == *"reason: gpu_availability"* || "$output" == *"reason: resource_availability"* || "$output" == *"reason: configuration_availability"* ]]; then
    if (( current_try < total_zones )); then
      printf 'Capacity unavailable in %s. Retrying the next candidate zone.\n' "$zone_to_try" >&2
      continue
    fi
  fi

  exit 1
done