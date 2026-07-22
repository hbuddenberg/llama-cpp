#!/usr/bin/env bash
# Download GGUF weights into per-model folders with their config.toml.
# Weights live on the host NVMe only; they are never baked into images.
set -euo pipefail

MODELS_DIR="$(cd "$(dirname "$0")/.." && pwd)/data/models"
mkdir -p "$MODELS_DIR"

command -v huggingface-cli >/dev/null || {
  echo "huggingface-cli not found. Install with: pip install -U 'huggingface_hub[cli]'"
  exit 1
}

# --- qwen2.5-32b-speed (engine: llama-atomic, speculative decoding) ---------
SPEED_DIR="$MODELS_DIR/qwen2.5-32b-speed"
mkdir -p "$SPEED_DIR"

huggingface-cli download bartowski/Qwen2.5-32B-Instruct-GGUF \
  Qwen2.5-32B-Instruct-IQ2_M.gguf --local-dir "$SPEED_DIR"
mv -f "$SPEED_DIR/Qwen2.5-32B-Instruct-IQ2_M.gguf" "$SPEED_DIR/model.gguf"

huggingface-cli download bartowski/Qwen2.5-0.5B-Instruct-GGUF \
  Qwen2.5-0.5B-Instruct-Q8_0.gguf --local-dir "$SPEED_DIR"
mv -f "$SPEED_DIR/Qwen2.5-0.5B-Instruct-Q8_0.gguf" "$SPEED_DIR/draft.gguf"

cat > "$SPEED_DIR/config.toml" <<'EOF'
[model]
alias  = "qwen-32b-speed"
engine = "llama-atomic"
file   = "model.gguf"

[args]
ctx_size     = 8192
n_gpu_layers = 99
flash_attn   = true
draft_model  = "draft.gguf"
draft_max    = 16
draft_min    = 4
load_timeout = 90
EOF

# --- llama3.1-8b-longctx (engine: llama-tom, 3-bit KV cache) ----------------
LONG_DIR="$MODELS_DIR/llama3.1-8b-longctx"
mkdir -p "$LONG_DIR"

huggingface-cli download bartowski/Meta-Llama-3.1-8B-Instruct-GGUF \
  Meta-Llama-3.1-8B-Instruct-Q5_K_M.gguf --local-dir "$LONG_DIR"
mv -f "$LONG_DIR/Meta-Llama-3.1-8B-Instruct-Q5_K_M.gguf" "$LONG_DIR/model.gguf"

cat > "$LONG_DIR/config.toml" <<'EOF'
[model]
alias  = "llama-3-long-context"
engine = "llama-tom"
file   = "model.gguf"

[args]
ctx_size     = 131072
n_gpu_layers = 99
flash_attn   = true
load_timeout = 90
extra        = ["--cache-type-k", "q3", "--cache-type-v", "q3"]
EOF

echo "Models ready under $MODELS_DIR"
