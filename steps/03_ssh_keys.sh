#!/usr/bin/env bash
# ─── Step 03: SSH Key Setup ─────────────────────────────────
# Sub-steps: generate_keypair | copy_public_key | verify_login
# ────────────────────────────────────────────────────────────
set -euo pipefail

CFG="$(dirname "$0")/../config.yml"
VPS_IP=$(grep -m1 "^vps_ip:" "$CFG" | sed 's/^[^:]*: *//;s/"//g')
DEPLOY_PASS=$(grep -m1 "^deployer_password:" "$CFG" | sed 's/^[^:]*: *//;s/"//g')
KEY_PATH=$(grep -m1 "^ssh_key_path:" "$CFG" | sed 's/^[^:]*: *//;s/"//g' | sed "s|\$HOME|$HOME|")

# ─── sub-steps ──────────────────────────────────────────────

generate_keypair() {
  if [[ -f "$KEY_PATH" ]]; then
    echo "Key already exists at $KEY_PATH — skipping generation"
    exit 0
  fi
  ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -q
}

copy_public_key() {
  sshpass -p"$DEPLOY_PASS" ssh-copy-id \
    -i "${KEY_PATH}.pub" \
    -o StrictHostKeyChecking=no \
    deployer@"$VPS_IP"
}

verify_login() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    deployer@"$VPS_IP" "echo key_login_ok"
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  generate_keypair) generate_keypair ;;
  copy_public_key)  copy_public_key  ;;
  verify_login)     verify_login     ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
