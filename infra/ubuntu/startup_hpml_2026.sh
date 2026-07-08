#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  build-essential \
  curl \
  git \
  git-lfs \
  pkg-config \
  python3-dev \
  python3-venv \
  tmux

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh
fi

cat >/etc/profile.d/hpml-2026.sh <<'EOF'
export HF_HUB_ENABLE_HF_TRANSFER=1
export TOKENIZERS_PARALLELISM=false
EOF

install -d -m 0755 /opt/hpml-2026
cat >/opt/hpml-2026/README-ubuntu-setup.txt <<'EOF'
This VM was provisioned for the hpml-2026-project repository
(HPML Group 20 -- Internalizing MCP Tool Knowledge in Small LLMs).

Expected project environment:
- Python 3.12 from Ubuntu 24.04
- Plain venv (via `uv venv`) with the notebook + fine-tuning stack from requirements.txt
- `uv sync` is a separate, optional step -- only needed if you also want the
  MCP server package/CLIs (plan-execute, *-mcp-server) from pyproject.toml.
  The fine-tuning notebook below does not require it.

Suggested next steps after cloning the repository:
1. uv venv
2. uv pip install -r requirements.txt
3. .venv/bin/python -c "import torch; print(torch.__version__); print(torch.version.cuda); print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'no-cuda')"
4. .venv/bin/python -c "import peft, trl, bitsandbytes; print('peft-trl-bitsandbytes-ok')"

This project does not use Unsloth or flash-attn. Fine-tuning uses QLoRA
(transformers + peft + trl + bitsandbytes) directly against google/gemma-4-E4B-it,
targeting a single A100 40GB (a2-highgpu-1g).

Notebook entrypoint: notebook/Planner_Internalization_Experiment_run_4.ipynb
EOF

python3 --version || true
uv --version || true
nvidia-smi || true