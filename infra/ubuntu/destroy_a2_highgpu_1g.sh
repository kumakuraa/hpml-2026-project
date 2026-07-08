#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PROJECT_ID="${PROJECT_ID:-aad-character-agent}"
export ZONE="${ZONE:-asia-northeast3-b}"
export VM_NAME="${VM_NAME:-hpml-2026-a100-1g}"
export DATA_DISK_NAME="${DATA_DISK_NAME:-${VM_NAME}-data}"

exec "$SCRIPT_DIR/destroy_gpu_vm.sh" "$@"