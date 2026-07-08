#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PROJECT_ID="${PROJECT_ID:-aad-character-agent}"
ZONE="${ZONE:-asia-northeast3-b}"
VM_NAME="${VM_NAME:-hpml-2026-a100-1g}"
LOCAL_INPUT_DIR="${LOCAL_INPUT_DIR:-$REPO_ROOT/input}"
REMOTE_REPO_DIR="${REMOTE_REPO_DIR:-hpml-2026-project}"

usage() {
  cat <<'EOF'
Usage:
  PROJECT_ID=my-project \
  ZONE=asia-northeast3-b \
  VM_NAME=hpml-2026-a100-1g \
  infra/ubuntu/sync_input_to_gpu_vm.sh

Optional environment variables:
  PROJECT_ID       GCP project ID
  ZONE             Compute Engine zone
  VM_NAME          VM name to receive the files
  LOCAL_INPUT_DIR  Local input directory to upload
                    (default: <repo>/input)
  REMOTE_REPO_DIR  Remote repository directory
                    (default: hpml-2026-project, relative to the remote home directory)
  DRY_RUN          Set to 1 to print commands without executing them

Behavior:
  - Creates REMOTE_REPO_DIR on the VM if needed
  - Copies the local input/ directory recursively into REMOTE_REPO_DIR
  - Resulting remote path is typically ~/hpml-2026-project/input
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

if [[ ! -d "$LOCAL_INPUT_DIR" ]]; then
  echo "Local input directory not found: $LOCAL_INPUT_DIR" >&2
  exit 1
fi

normalize_remote_repo_dir() {
  local raw_dir="$1"

  case "$raw_dir" in
    '$HOME')
      printf '.'
      ;;
    '$HOME'/*)
      printf '%s' "${raw_dir#\$HOME/}"
      ;;
    '${HOME}')
      printf '.'
      ;;
    '${HOME}'/*)
      printf '%s' "${raw_dir#\$\{HOME\}/}"
      ;;
    '~')
      printf '.'
      ;;
    ~/*)
      printf '%s' "${raw_dir#~/}"
      ;;
    *)
      printf '%s' "$raw_dir"
      ;;
  esac
}

REMOTE_REPO_DIR_NORMALIZED="$(normalize_remote_repo_dir "$REMOTE_REPO_DIR")"

if [[ "$REMOTE_REPO_DIR_NORMALIZED" == /* ]]; then
  REMOTE_REPO_DIR_MKDIR="$REMOTE_REPO_DIR_NORMALIZED"
  REMOTE_REPO_DIR_SCP="$REMOTE_REPO_DIR_NORMALIZED"
elif [[ "$REMOTE_REPO_DIR_NORMALIZED" == "." ]]; then
  REMOTE_REPO_DIR_MKDIR='"$HOME"'
  REMOTE_REPO_DIR_SCP='.'
else
  REMOTE_REPO_DIR_MKDIR='"$HOME"'"/$REMOTE_REPO_DIR_NORMALIZED"
  REMOTE_REPO_DIR_SCP="$REMOTE_REPO_DIR_NORMALIZED"
fi

mkdir_remote_dir_cmd=(
  gcloud compute ssh "$VM_NAME"
  --project="$PROJECT_ID"
  --zone="$ZONE"
  --command="mkdir -p ${REMOTE_REPO_DIR_MKDIR}"
)

scp_input_cmd=(
  gcloud compute scp
  --recurse
  --project="$PROJECT_ID"
  --zone="$ZONE"
  "$LOCAL_INPUT_DIR"
  "${VM_NAME}:${REMOTE_REPO_DIR_SCP}"
)

printf 'Prepared remote directory command:\n'
printf ' %q' "${mkdir_remote_dir_cmd[@]}"
printf '\n'
printf 'Prepared input sync command:\n'
printf ' %q' "${scp_input_cmd[@]}"
printf '\n'

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  exit 0
fi

"${mkdir_remote_dir_cmd[@]}"
"${scp_input_cmd[@]}"