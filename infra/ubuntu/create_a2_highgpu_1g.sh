#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PROJECT_ID="${PROJECT_ID:-aad-character-agent}"
export ZONE="${ZONE:-asia-northeast3-b}"
export VM_NAME="${VM_NAME:-hpml-2026-a100-1g}"
export MACHINE_TYPE="${MACHINE_TYPE:-a2-highgpu-1g}"

exec "$SCRIPT_DIR/create_gpu_vm.sh" "$@"