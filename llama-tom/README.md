# llama-tom — Long-Context TurboQuant Engine

CUDA build pipeline for the TurboQuant 3-bit KV-cache llama.cpp fork, targeting Compute Capability 8.6 (RTX 3060).

## What it does

Builds `llama-server` from [`TheTom/llama-cpp-turboquant`](https://github.com/TheTom/llama-cpp-turboquant) — a fork that compresses the KV cache to 3 bits. This makes 131 072-token context windows feasible on a 12 GB GPU:

| | Standard FP16 | TurboQuant Q3 |
|--|---------------|---------------|
| KV cache at 131 072 ctx | ~16 GB | ~3 GB |
| Fits in 12 GB VRAM? | ✗ | ✓ |

## Default model profile: `llama-3-long-context`

| Parameter | Value |
|-----------|-------|
| Model | Llama-3.1-8B-Instruct Q5_K_M (~5.7 GB VRAM) |
| Context | 131 072 tokens |
| KV cache | Q3 (3-bit, ~3 GB VRAM) |
| **Total VRAM** | **~9.5 GB** |
| GPU layers | 99 (fully offloaded) |
| Extra flags | `--cache-type-k q3 --cache-type-v q3 --flash-attn` |

`config.toml` for this profile lives in `nuc-infra/data/models/llama3.1-8b-longctx/`.

## Build

The image is built automatically by GitHub Actions on push to `main` when `llama-tom/**` changes.

To build locally (requires CUDA toolkit):

```bash
docker build --build-arg SOURCE_REF=main -t llama-tom ./llama-tom
```

To pin to a specific upstream commit:

```bash
docker build --build-arg SOURCE_REF=<sha> -t llama-tom ./llama-tom
```

The `SOURCE_REF` build arg accepts any git ref (branch, tag, or SHA). For reproducible production builds, pin to a SHA and set `ENGINE_SOURCE_REF=<sha>` in `nuc-infra/.env`.

## Image

`ghcr.io/hbuddenberg/llama-tom:latest` — two-stage build:
- Stage 1: `nvidia/cuda:12.4.1-devel-ubuntu22.04` — shallow clone + CMake CUDA build
- Stage 2: `nvidia/cuda:12.4.1-runtime-ubuntu22.04` — minimal runtime with `llama-server` binary only

Exposes port 8080. Launched dynamically by `ai-wrapper` via the host Podman socket with `--device nvidia.com/gpu=all`.
