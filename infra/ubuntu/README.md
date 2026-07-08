# HPML 2026 — A100 GPU VM on GCP

This workspace contains minimal Google Compute Engine scripts for fine-tuning Gemma 4 E4B
(HPML Group 20 — Internalizing MCP Tool Knowledge in Small LLMs) on a single NVIDIA A100 40GB
GPU VM (`a2-highgpu-1g`).

The Ubuntu path uses a Deep Learning VM image (Ubuntu 24.04, Python 3.12, current NVIDIA driver)
and a plain `uv`-managed venv on top of it. Fine-tuning uses QLoRA directly via
`transformers` + `peft` + `trl` + `bitsandbytes` (see `requirements.txt`) — this project does
**not** use Unsloth or a prebuilt `flash-attn` wheel, and does not pin a specific `torch`/CUDA
build; any reasonably recent CUDA works fine on A100 (see the main project README for the
CUDA-version discussion).

## Target VM preset

- `a2-highgpu-1g`: `A100 40GB x1`
- Intended use: `notebook/Planner_Internalization_Experiment_run_4.ipynb` (Gemma 4 E4B QLoRA SFT,
  Config A / plan-only and related data ablations)

Only the 40GB shape (`a2-highgpu-1g`) is set up in this repository. There are no
`a2-ultragpu-1g` (80GB) wrapper scripts here.

## Current status

The active GCP project is `aad-character-agent`, and `compute.googleapis.com` is enabled.
The default zone is `asia-northeast3-b` (empirically easier to get A100 capacity than the
`us-central1-*` zones).

The create script defaults to a Deep Learning VM image family for Ubuntu 24.04:

- `common-cu129-ubuntu-2404-nvidia-580`

This gives Ubuntu 24.04, Python 3.12, and a current NVIDIA 580 driver line out of the box.
The repository's own `requirements.txt` then manages the actual ML stack (torch, peft, trl,
bitsandbytes, accelerate, wandb) via a plain venv, independent of the host CUDA/driver version.

If you want a pinned image instead of a moving family target, use `IMAGE_NAME`.

By default the VM also runs [`startup_hpml_2026.sh`](startup_hpml_2026.sh) on first boot to
install `uv`, `git`, `git-lfs`, build tools, and `tmux`, which the notebook workflow below
relies on.

## Script layout

The generic entrypoints:

- `infra/ubuntu/create_gpu_vm.sh`
- `infra/ubuntu/start_gpu_vm.sh`
- `infra/ubuntu/stop_gpu_vm.sh`
- `infra/ubuntu/destroy_gpu_vm.sh`

The `*_a2_highgpu_1g.sh` files are project-specific wrappers that export
`PROJECT_ID=aad-character-agent`, `ZONE=asia-northeast3-b`, `VM_NAME=hpml-2026-a100-1g`, and
(for create) `MACHINE_TYPE=a2-highgpu-1g`, then exec the matching generic script.

`infra/ubuntu/sync_input_to_gpu_vm.sh` is a separate utility for copying a local `input/`
directory to the VM. Its defaults now match the other scripts (`ZONE=asia-northeast3-b`,
`VM_NAME=hpml-2026-a100-1g`, `REMOTE_REPO_DIR=hpml-2026-project`), so it can be run with no
overrides once the VM name/zone match your actual instance.

## Create the VM

Run these commands from the repository root.

Dry run:

```bash
DRY_RUN=1 infra/ubuntu/create_a2_highgpu_1g.sh
```

Actual create:

```bash
PROJECT_ID=aad-character-agent \
ZONE=asia-northeast3-b \
VM_NAME=hpml-2026-a100-1g \
infra/ubuntu/create_a2_highgpu_1g.sh
```

If the preferred zone is temporarily out of capacity, add fallback zones so the script retries
automatically on stockout-style errors:

```bash
PROJECT_ID=aad-character-agent \
ZONE=asia-northeast3-b \
FALLBACK_ZONES=asia-northeast3-a,asia-northeast1-a \
VM_NAME=hpml-2026-a100-1g \
infra/ubuntu/create_a2_highgpu_1g.sh
```

If you want to skip the default first-boot provisioning script:

```bash
STARTUP_SCRIPT_FILE= \
infra/ubuntu/create_a2_highgpu_1g.sh
```

## Destroy the VM

Dry run:

```bash
DRY_RUN=1 infra/ubuntu/destroy_a2_highgpu_1g.sh
```

Actual destroy:

```bash
PROJECT_ID=aad-character-agent \
ZONE=asia-northeast3-b \
VM_NAME=hpml-2026-a100-1g \
infra/ubuntu/destroy_a2_highgpu_1g.sh
```

The destroy script also deletes the extra `${VM_NAME}-data` disk if it remains after VM
deletion.

## Sync local input/ to the VM

To upload the repository's local `input/` directory to the VM, use:

```bash
PROJECT_ID=aad-character-agent \
ZONE=asia-northeast3-b \
VM_NAME=hpml-2026-a100-1g \
REMOTE_REPO_DIR=hpml-2026-project \
infra/ubuntu/sync_input_to_gpu_vm.sh
```

This creates `~/hpml-2026-project` on the VM if needed and copies the local `input/` tree so
the resulting remote path is `~/hpml-2026-project/input`.

Dry run:

```bash
DRY_RUN=1 PROJECT_ID=aad-character-agent ZONE=asia-northeast3-b VM_NAME=hpml-2026-a100-1g \
infra/ubuntu/sync_input_to_gpu_vm.sh
```

## Stop or start the VM

Use stop when you want to keep the VM and its persistent disks, but stop paying for the running
A100, vCPUs, and RAM.

For A2 shapes with Local SSD, Compute Engine requires an explicit `discard-local-ssd` choice on
stop. The scripts default to `DISCARD_LOCAL_SSD=true`, which is usually correct because Local
SSD contents are ephemeral.

Dry run stop:

```bash
DRY_RUN=1 infra/ubuntu/stop_a2_highgpu_1g.sh
```

Actual stop:

```bash
PROJECT_ID=aad-character-agent \
ZONE=asia-northeast3-b \
VM_NAME=hpml-2026-a100-1g \
infra/ubuntu/stop_a2_highgpu_1g.sh
```

Dry run start:

```bash
DRY_RUN=1 infra/ubuntu/start_a2_highgpu_1g.sh
```

Actual start:

```bash
PROJECT_ID=aad-character-agent \
ZONE=asia-northeast3-b \
VM_NAME=hpml-2026-a100-1g \
infra/ubuntu/start_a2_highgpu_1g.sh
```

Notes:

- Always use the actual zone where the VM exists. If a fallback zone was used at create time,
  use that zone for every subsequent `ssh`/`stop`/`start`/`destroy` call.
- Stopping the VM preserves the boot disk, attached persistent disks, metadata, and IP
  configuration.
- Persistent disk charges continue while the VM is stopped.
- GPU-backed A2 instances cannot use suspend, so stop/start is the practical cost-saving
  lifecycle operation when you do not want to destroy the VM.
- Restart is not guaranteed. A stopped A100 VM can fail to start later if the original zone is
  in `STOCKOUT`.

## Cross-zone recovery after start stockout

If a stopped A100 VM cannot restart because its original zone has no capacity, use one of these
paths.

### Fastest path: rebuild in a zone that has capacity

If you do not need the old VM's filesystem state, create a fresh VM in another zone that
currently has A100 capacity:

```bash
PROJECT_ID=aad-character-agent \
ZONE=asia-northeast3-a \
VM_NAME=hpml-2026-a100-1g \
MACHINE_TYPE=a2-highgpu-1g \
infra/ubuntu/create_gpu_vm.sh
```

### Stateful path: restore the boot and data disks into another zone

If you need the previous filesystem state (repository checkout, `.venv`, downloaded model
weights) stored on the old boot/data disks, you must move the disk contents across zones first,
since zonal persistent disks cannot attach directly to a VM in a different zone.

Typical recovery flow:

1. Create a snapshot of the stopped boot disk.
2. Create a snapshot of the stopped data disk.
3. Create new disks in the target zone from those snapshots.
4. Create a new VM in the target zone using the restored boot disk and attach the restored data
   disk.
5. Validate the recovered VM before deleting the old stopped VM.

Required IAM:

- `compute.snapshots.create` to create recovery snapshots
- the normal instance and disk create permissions already used by the create script

If you do not have `compute.snapshots.create`, a stateful cross-zone recovery cannot be
completed from this repository alone. In that case, either ask an administrator to grant the
permission or accept a fresh rebuild in the target zone.

### When the virtual environment survives

- Same VM, same zone, successful `start`: the existing `.venv` survives.
- Fresh VM in another zone: `.venv` does not survive; run `uv venv && uv pip install -r
  requirements.txt` again.
- Cross-zone restore from the old boot disk snapshot: `.venv` usually survives if it lived on
  the boot disk.

## Common overrides

Use a plain Ubuntu image instead of a Deep Learning VM image:

```bash
IMAGE_FAMILY=ubuntu-2204-lts \
IMAGE_PROJECT=ubuntu-os-cloud \
infra/ubuntu/create_a2_highgpu_1g.sh
```

Use a pinned Deep Learning VM image name instead of the latest family image:

```bash
IMAGE_NAME=common-cu129-ubuntu-2404-nvidia-580-v20260616 \
infra/ubuntu/create_a2_highgpu_1g.sh
```

Change zone and disk sizes:

```bash
ZONE=asia-northeast1-a \
BOOT_DISK_SIZE=300GB \
DATA_DISK_SIZE=1000GB \
infra/ubuntu/create_a2_highgpu_1g.sh
```

The `Disk size is larger than image size` warning is expected here. Compute Engine expands the
boot disk to the requested size on current Ubuntu / Deep Learning VM images.

## After creation

Connect:

```bash
gcloud compute ssh hpml-2026-a100-1g --zone asia-northeast3-b
```

If creation succeeded in a fallback zone, use that actual zone for `ssh` and for
`infra/ubuntu/destroy_a2_highgpu_1g.sh`.

Verify GPU:

```bash
nvidia-smi
```

Clone the repository and set up the environment on the VM:

```bash
git clone https://github.com/<org>/hpml-2026-project.git
cd hpml-2026-project
uv venv
uv pip install -r requirements.txt
.venv/bin/python -c "import torch; print(torch.__version__); print(torch.version.cuda); print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'no-cuda')"
.venv/bin/python -c "import peft, trl, bitsandbytes; print('peft-trl-bitsandbytes-ok')"
```

`uv sync` is a separate, optional step for the MCP server package/CLIs (`plan-execute`,
`*-mcp-server`) defined in `pyproject.toml`. The fine-tuning notebook does not need it.

## Remote notebook workflow

The safest default is to run Jupyter on the VM, keep it bound to `127.0.0.1`, and access it
through SSH port forwarding.

### Web UI from your local machine

Open an SSH tunnel from your local machine:

```bash
gcloud compute ssh hpml-2026-a100-1g --zone asia-northeast3-b -- -L 8888:localhost:8888
```

On the VM, start a persistent shell session for notebook work:

```bash
tmux new -s notebook
cd ~/hpml-2026-project
.venv/bin/jupyter notebook --no-browser --ip=127.0.0.1 --port=8888
```

Jupyter prints a local URL with a token such as `http://127.0.0.1:8888/tree?token=...`. Open the
same path on your local machine as `http://localhost:8888/tree?token=...`.

Useful tmux commands:

- Detach and leave Jupyter running: `Ctrl-b` then `d`
- Re-attach later: `tmux attach -t notebook`
- Stop Jupyter cleanly: re-attach and press `Ctrl-c`

If local port `8888` is already in use, map a different local port:

```bash
gcloud compute ssh hpml-2026-a100-1g --zone asia-northeast3-b -- -L 8889:localhost:8888
```

Then open `http://localhost:8889/tree?token=...`.

### VS Code notebook UI against the remote VM

You can display and execute the notebook in VS Code instead of the browser UI.

1. Install the VS Code extensions `Remote - SSH`, `Jupyter`, and `Python` on your local machine.
2. Run `Remote-SSH: Connect to Host...` from VS Code and connect to the VM. A simple host entry
   is:

	```sshconfig
	Host hpml-2026-a100-1g
	  HostName <VM external IP>
	  User <your-username>
	  IdentityFile ~/.ssh/google_compute_engine
	```

	If you prefer, you can also keep using `gcloud compute ssh` from a terminal and let VS Code
	connect through the same SSH config file.
3. In the remote VS Code window, open `~/hpml-2026-project`.
4. If the environment is not set up yet, run:

	```bash
	uv venv
	uv pip install -r requirements.txt
	```
5. Register the project kernel on the VM once:

	```bash
	cd ~/hpml-2026-project
	.venv/bin/python -m ipykernel install --user --name hpml-2026-project --display-name "Python (.venv) hpml-2026-project"
	```
6. Open `notebook/Planner_Internalization_Experiment_run_4.ipynb` in the remote VS Code window.
7. Use `Select Kernel` in the notebook toolbar and choose `Python (.venv) hpml-2026-project`.
8. Execute cells normally. The kernel and GPU execution stay on the VM, while the notebook UI
   stays in VS Code.

If VS Code does not list the kernel immediately, run `Python: Select Interpreter`, choose
`~/hpml-2026-project/.venv/bin/python`, close the notebook tab, and open it again.

If you used a standard Ubuntu image instead of the Deep Learning VM image, you may still need to
complete NVIDIA driver and CUDA setup depending on the image state.
