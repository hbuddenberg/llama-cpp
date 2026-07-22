#!/usr/bin/env bash
# Publish the ai-wrapper endpoint (host port 5120) on the tailnet.
# Clients then reach it at http://<tailnet-hostname>:5120/v1
#
# Fix 14: SECURITY WARNING
# -------------------------
# This command exposes the ai-wrapper port to EVERY device on your Tailscale
# tailnet, including shared nodes and exit-node peers. Treat the tailnet as a
# semi-public network: WRAPPER_API_KEY MUST be set to a strong, random value
# (e.g. openssl rand -hex 32) before running this script. An empty or weak key
# allows any tailnet peer to consume your GPU and models without restriction.
# -------------------------
set -euo pipefail

PORT="${1:-5120}"

command -v tailscale >/dev/null || {
  echo "tailscale CLI not found on this host."
  exit 1
}

tailscale serve --bg --tcp "$PORT" "tcp://127.0.0.1:${PORT}"
tailscale serve status
