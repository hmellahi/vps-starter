#!/usr/bin/env bash
# ─── Step 05: Harden SSH ────────────────────────────────────
# Sub-steps: patch_config | validate | restart
# ────────────────────────────────────────────────────────────
set -euo pipefail

# Load .env file
ENV_FILE="$(dirname "$0")/../.env"
get_env() {
  grep "^$1=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^["'\'']\(.*\)["'\'']$/\1/' | sed "s|\$HOME|$HOME|"
}

VPS_IP=$(get_env "VPS_IP")
KEY_PATH=$(get_env "SSH_KEY_PATH")

ssh_sudo() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    root@"$VPS_IP" sudo "$@"
}

# ─── sub-steps ──────────────────────────────────────────────

patch_config() {
  # Check if SSH is already hardened by checking PermitRootLogin
  local already_hardened=$(ssh_sudo grep -q "^PermitRootLogin no" /etc/ssh/sshd_config && echo "YES" || echo "NO")
  
  if [[ "$already_hardened" == "YES" ]]; then
    echo "SSH config already hardened — skipping"
    return 0
  fi
  
  ssh_sudo bash -c '
    CONF=/etc/ssh/sshd_config
    sed -i "s/^#*PermitRootLogin .*/PermitRootLogin no/"              "$CONF"
    sed -i "s/^#*PasswordAuthentication .*/PasswordAuthentication no/" "$CONF"
    sed -i "s/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/"   "$CONF"
    sed -i "s/^#*MaxAuthTries .*/MaxAuthTries 3/"                    "$CONF"
    sed -i "/^AllowUsers/d"                                          "$CONF"
    echo "AllowUsers deployer" >> "$CONF"
  '
}

validate() {
  ssh_sudo sshd -t
}

restart() {
  # Try both service names (sshd for RHEL/CentOS, ssh for Debian/Ubuntu)
  if ssh_sudo systemctl restart ssh 2>/dev/null; then
    return 0
  elif ssh_sudo systemctl restart sshd 2>/dev/null; then
    return 0
  else
    echo "Failed to restart SSH service (tried both 'ssh' and 'sshd')" >&2
    return 1
  fi
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  patch_config) patch_config ;;
  validate)     validate     ;;
  restart)      restart      ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
