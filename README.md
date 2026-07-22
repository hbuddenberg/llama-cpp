# llama-cpp — NUC AI Appliance

A self-hosted AI appliance for a headless uCore host (Fedora CoreOS + Podman CDI) with an RTX 3060 12 GB eGPU. Exposes a single OpenAI-compatible endpoint on port 5120, published to your tailnet via Tailscale.

## Quick Start

```bash
# Clone and install in one shot
git clone https://github.com/hbuddenberg/llama-cpp
GH_USER=hbuddenberg WRAPPER_API_KEY=<your-strong-key> bash llama-cpp/nuc-infra/scripts/install.sh
```

Or via curl (no prior clone needed):

```bash
curl -fsSL https://raw.githubusercontent.com/hbuddenberg/llama-cpp/main/nuc-infra/scripts/install.sh | \
  GH_USER=hbuddenberg WRAPPER_API_KEY=<your-strong-key> bash
```

The installer handles: dependency detection, `.env` generation, GHCR image pulls, service startup, model download, and Tailscale exposure.

## Architecture

```
Client (LibreChat / Hermes / any OpenAI client)
  │
  ▼  port 5120 (Tailscale TCP serve)
ai-wrapper                    ← single OpenAI endpoint; VRAM Director
  │  asyncio.Condition guard — only ONE engine active at a time
  ├─▶ llama-atomic container  ← speculative decoding fork  (Qwen 32B IQ2_M)
  └─▶ llama-tom container     ← TurboQuant 3-bit KV fork   (Llama 3.1 8B 131k ctx)
        │
        └── models mounted from host NVMe (./nuc-infra/data/models/)
```

**Hard rules:**
- The two inference engines **NEVER run concurrently** — `ai-wrapper` stops the active engine, waits 1.5 s (NVIDIA driver eGPU memory release), then starts the target
- Total infra idle RAM < 1.2 GB (MongoDB WiredTiger capped at 250 MB, engines not running at idle)
- All Podman volume mounts use SELinux flags (`:z` / `:ro,z`)

## Components

| Directory | Description | Image |
|-----------|-------------|-------|
| [`nuc-infra/`](nuc-infra/) | Podman Compose orchestration, model configs, scripts | *(no image)* |
| [`ai-wrapper/`](ai-wrapper/) | FastAPI VRAM Director — OpenAI-compatible proxy | `ghcr.io/hbuddenberg/ai-wrapper` |
| [`llama-atomic/`](llama-atomic/) | CUDA build for the speculative-decoding llama.cpp fork | `ghcr.io/hbuddenberg/llama-atomic` |
| [`llama-tom/`](llama-tom/) | CUDA build for the TurboQuant 3-bit KV-cache fork | `ghcr.io/hbuddenberg/llama-tom` |

## Models

| Alias | Engine | Model | VRAM | Use case |
|-------|--------|-------|------|----------|
| `qwen-32b-speed` | llama-atomic | Qwen2.5-32B IQ2_M + 0.5B draft | ~11.5 GB | Speed — speculative decoding 1.5–2.5× throughput |
| `llama-3-long-context` | llama-tom | Llama-3.1-8B Q5_K_M | ~9.5 GB | Long context — 131 072 tokens with 3-bit KV cache |

Add a model by creating a folder under `nuc-infra/data/models/` with a GGUF and a `config.toml` — no code change needed.

## Requirements

- Fedora CoreOS (uCore) / Ubuntu 22.04+ / Debian 12+ / Arch
- Podman ≥ 4.0
- RTX 3060 12 GB via Thunderbolt 3 CDI (`--device nvidia.com/gpu=all`)
- Tailscale (optional, for tailnet exposure)

## CI / CD

Three GitHub Actions workflows build and push images to GHCR on push to `main`, triggered by path:

| Workflow | Trigger path |
|----------|-------------|
| `deploy-ai-wrapper` | `ai-wrapper/**` |
| `deploy-llama-atomic` | `llama-atomic/**` |
| `deploy-llama-tom` | `llama-tom/**` |

## Feature branches

| Branch | Component |
|--------|-----------|
| `feature/nuc-infra` | Orchestration and scripts |
| `feature/ai-wrapper` | VRAM Director |
| `feature/llama-atomic` | Speculative decoding engine |
| `feature/llama-tom` | Long-context engine |
