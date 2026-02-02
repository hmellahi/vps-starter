#!/usr/bin/env bash
# Test SSH connection to VPS

set -euo pipefail

# Load .env file
ENV_FILE="$(dirname "$0")/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ .env file not found! Copy .env.example to .env first." >&2
  exit 1
fi

# Parse .env (ignore comments and empty lines)
get_env() {
  grep "^$1=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^["'\'']\(.*\)["'\'']$/\1/' | sed "s|\$HOME|$HOME|"
}

VPS_IP=$(get_env "VPS_IP")
SSH_KEY_PATH=$(get_env "SSH_KEY_PATH")
ROOT_PASS=$(get_env "ROOT_PASSWORD")

echo "=== SSH Connection Test ==="
echo "VPS IP: $VPS_IP"
echo ""

if [[ -n "$SSH_KEY_PATH" ]]; then
  echo "Testing SSH key authentication..."
  echo "Key path: $SSH_KEY_PATH"
  
  if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "❌ Key file does not exist: $SSH_KEY_PATH"
    exit 1
  fi
  
  echo ""
  echo "Running: ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o BatchMode=yes root@$VPS_IP 'echo SUCCESS'"
  echo ""
  
  ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes root@"$VPS_IP" 'echo "✅ SSH connection successful!"'
  
elif [[ -n "$ROOT_PASS" ]]; then
  echo "Testing password authentication..."
  echo "(Password is hidden)"
  echo ""
  
  if ! command -v sshpass &> /dev/null; then
    echo "❌ sshpass is not installed. Run: brew install sshpass"
    exit 1
  fi
  
  sshpass -p"$ROOT_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"$VPS_IP" 'echo "✅ SSH connection successful!"'
  
else
  echo "❌ Neither SSH_KEY_PATH nor ROOT_PASSWORD is configured in .env"
  exit 1
fi
