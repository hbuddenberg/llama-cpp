# llama-atomic — Speculative Decoding Engine

CUDA build pipeline for the speculative-decoding llama.cpp fork, targeting Compute Capability 8.6 (RTX 3060).

## What it does

Builds `llama-server` from [`AtomicBot-ai/atomic-llama-cpp-turboquant`](https://github.com/AtomicBot-ai/atomic-llama-cpp-turboquant) — a fork that supports speculative decoding: a small draft model generates token candidates in batches, and the large model verifies them in a single forward pass. This delivers **1.5–2.5× throughput** with no quality loss (verification is exact).

## Default model profile: `qwen-32b-speed`

| Parameter | Value |
|-----------|-------|
| Main model | Qwen2.5-32B-Instruct IQ2_M (~10.4 GB VRAM) |
| Draft model | Qwen2.5-0.5B-Instruct Q8_0 (~0.6 GB VRAM) |
| Context | 8 192 tokens |
| KV cache | FP16 (~1 GB) |
| **Total VRAM** | **~12 GB** |
| GPU layers | 99 (fully offloaded) |

`config.toml` for this profile lives in `nuc-infra/data/models/qwen2.5-32b-speed/`.

## Build

The image is built automatically by GitHub Actions on push to `main` when `llama-atomic/**` changes.

To build locally (requires CUDA toolkit):

```bash
docker build --build-arg SOURCE_REF=main -t llama-atomic ./llama-atomic
```

To pin to a specific upstream commit:

```bash
docker build --build-arg SOURCE_REF=<sha> -t llama-atomic ./llama-atomic
```

The `SOURCE_REF` build arg accepts any git ref (branch, tag, or SHA). For reproducible production builds, pin to a SHA and set `ENGINE_SOURCE_REF=<sha>` in `nuc-infra/.env`.

## Image

`ghcr.io/hbuddenberg/llama-atomic:latest` — two-stage build:
- Stage 1: `nvidia/cuda:12.4.1-devel-ubuntu22.04` — shallow clone + CMake CUDA build
- Stage 2: `nvidia/cuda:12.4.1-runtime-ubuntu22.04` — minimal runtime with `llama-server` binary only

Exposes port 8080. Launched dynamically by `ai-wrapper` via the host Podman socket with `--device nvidia.com/gpu=all`.
