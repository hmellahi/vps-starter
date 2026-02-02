#!/usr/bin/env bash
# ─── Step 03: SSH Key Setup ─────────────────────────────────
# Sub-steps: generate_keypair | verify_login
# ────────────────────────────────────────────────────────────
set -euo pipefail

# Load .env file
ENV_FILE="$(dirname "$0")/../.env"
get_env() {
  grep "^$1=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^["'\'']\(.*\)["'\'']$/\1/' | sed "s|\$HOME|$HOME|"
}

VPS_IP=$(get_env "VPS_IP")
KEY_PATH=$(get_env "SSH_KEY_PATH")

# ─── sub-steps ──────────────────────────────────────────────

generate_keypair() {
  if [[ -f "$KEY_PATH" ]]; then
    echo "Key already exists at $KEY_PATH — skipping generation"
    exit 0
  fi
  ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -q
}

verify_login() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    deployer@"$VPS_IP" "echo 'SSH key login successful'"
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  generate_keypair) generate_keypair ;;
  verify_login)     verify_login     ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
