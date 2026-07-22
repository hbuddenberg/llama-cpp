# ai-wrapper — VRAM Director

Single OpenAI-compatible endpoint for the NUC AI appliance. Proxies requests to one of two inference engines (llama-atomic or llama-tom), hot-swapping between them while ensuring the RTX 3060 VRAM is never shared between engines.

## How it works

1. Client sends a request to `/v1/chat/completions` with a model alias (e.g. `qwen-32b-speed`)
2. `ai-wrapper` resolves the alias to an engine via the model registry (folder-based autodiscovery)
3. If a different engine is active, it stops it, waits 1.5 s for NVIDIA driver memory release, then starts the target engine via the host Podman socket
4. The request is proxied (streaming or non-streaming) to the engine's `llama-server` at port 8080
5. On completion, the engine slot is released; another request may reuse it or trigger another swap

Concurrency is managed by a single `asyncio.Condition` guard — the swap waits for all in-flight requests to drain before stopping the active engine.

## Model autodiscovery

Each model is a folder under `data/models/` containing:

```
data/models/
└── qwen2.5-32b-speed/
    ├── model.gguf
    ├── draft.gguf          # optional (speculative decoding)
    └── config.toml
```

```toml
[model]
alias  = "qwen-32b-speed"   # exposed in /v1/models
engine = "llama-atomic"     # image: ghcr.io/${GH_USER}/llama-<engine>:latest

[args]
ctx_size     = 8192
n_gpu_layers = 99
flash_attn   = true
draft_model  = "draft.gguf"
draft_max    = 16
extra        = ["--cache-type-k", "q3", "--cache-type-v", "q3"]
```

Adding a model = creating a folder + `config.toml`. No code or compose change needed.

## Endpoints

| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /health` | None | Liveness probe |
| `GET /v1/status` | Bearer | Active model and engine |
| `GET /v1/models` | Bearer | List discovered model aliases |
| `POST /v1/chat/completions` | Bearer | OpenAI-compatible inference (streaming + non-streaming) |

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `WRAPPER_API_KEY` | Yes | — | Bearer token for all authenticated endpoints |
| `ALLOW_ANONYMOUS` | No | unset | Set to `true` to skip auth (trusted networks only) |
| `MODELS_DIR` | No | `/models` | Path inside the container where models are mounted |
| `MODELS_HOST_DIR` | Yes | — | Host path mounted into dynamically launched engine containers |
| `PODMAN_URL` | No | `unix:///run/podman/podman.sock` | Podman socket URL |
| `ENGINE_NETWORK` | No | `nuc-infra_ai-isolated-net` | Podman network for engine containers |
| `GH_USER` | Yes | — | GitHub username owning the GHCR images |

## Local development

```bash
pip install -r requirements.txt
WRAPPER_API_KEY=dev MODELS_DIR=./data/models GH_USER=hbuddenberg uvicorn main:app --reload
```
