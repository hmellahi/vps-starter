#!/usr/bin/env bash
# ─── Step 11: SSL Certificates (Let's Encrypt) ──────────────
# Sub-steps: install_certbot | obtain_primary_cert | obtain_additional_cert
# Requires: port 80 free on VPS (e.g. nginx not running yet).
# Certs go to /etc/letsencrypt/live/<first-domain>/ for use in nginx.
# ────────────────────────────────────────────────────────────
set -euo pipefail

ENV_FILE="$(dirname "$0")/../.env"
get_env() {
  grep "^$1=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | sed 's/^["'\'']\(.*\)["'\'']$/\1/' | sed "s|\$HOME|$HOME|" || true
}

VPS_IP=$(get_env "VPS_IP")
KEY_PATH=$(get_env "SSH_KEY_PATH")
LETSENCRYPT_EMAIL=$(get_env "LETSENCRYPT_EMAIL")
PRIMARY_SSL_DOMAINS=$(get_env "PRIMARY_SSL_DOMAINS")
ADDITIONAL_SSL_DOMAINS=$(get_env "ADDITIONAL_SSL_DOMAINS")

ssh_sudo() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" sudo "$@"
}

ssh_deploy() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" "$@"
}

# Skip if SSL not configured (optional step)
is_ssl_configured() {
  [[ -n "$LETSENCRYPT_EMAIL" && -n "$PRIMARY_SSL_DOMAINS" ]] && \
  [[ "$LETSENCRYPT_EMAIL" != "your@email.com" ]] && \
  [[ "$PRIMARY_SSL_DOMAINS" != *"your-"* ]]
}

# Convert "domain1, domain2" to -d domain1 -d domain2 (no leading space)
domains_to_args() {
  local domains="$1"
  local args=""
  local first=1
  while IFS=',' read -ra parts; do
    for p in "${parts[@]}"; do
      p=$(echo "$p" | tr -d ' ')
      [[ -z "$p" ]] && continue
      if [[ "$first" -eq 1 ]]; then
        args="-d $p"
        first=0
      else
        args="$args -d $p"
      fi
    done
  done <<< "$domains"
  echo "$args"
}

install_certbot() {
  if ! is_ssl_configured; then
    echo "SSL skipped: set LETSENCRYPT_EMAIL and PRIMARY_SSL_DOMAINS in .env to enable"
    return 0
  fi

  # Check if certbot already installed
  if ssh_sudo which certbot >/dev/null 2>&1; then
    echo "certbot already installed — skipping"
    return 0
  fi

  echo "Installing certbot (Let's Encrypt client)..."
  ssh_sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq
  ssh_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y certbot
  if ! ssh_sudo which certbot >/dev/null 2>&1; then
    echo "ERROR: certbot install failed or certbot not in PATH" >&2
    exit 1
  fi
  echo "certbot installed"
}

obtain_primary_cert() {
  if ! is_ssl_configured; then
    return 0
  fi

  local args
  args=$(domains_to_args "$PRIMARY_SSL_DOMAINS")
  if [[ -z "$args" ]]; then
    echo "PRIMARY_SSL_DOMAINS is empty — skipping primary cert"
    return 0
  fi

  # Check if primary cert already exists (first domain = cert name)
  local first_domain
  first_domain=$(echo "$PRIMARY_SSL_DOMAINS" | cut -d',' -f1 | tr -d ' ')
  if ssh_sudo test -d "/etc/letsencrypt/live/$first_domain"; then
    echo "Primary cert for $first_domain already exists — skipping"
    return 0
  fi

  echo "Obtaining certificate for: $PRIMARY_SSL_DOMAINS"
  # Standalone mode: certbot binds to port 80. Pass script via stdin to avoid quoting issues over SSH.
  printf 'certbot certonly --standalone --non-interactive --agree-tos -m %s %s\n' \
    "$(printf '%q' "$LETSENCRYPT_EMAIL")" "$args" | ssh_sudo bash
  echo "Primary certificate obtained"
}

obtain_additional_cert() {
  if ! is_ssl_configured; then
    return 0
  fi

  [[ -z "$ADDITIONAL_SSL_DOMAINS" ]] && return 0
  [[ "$ADDITIONAL_SSL_DOMAINS" == *"your-"* ]] && return 0

  local args
  args=$(domains_to_args "$ADDITIONAL_SSL_DOMAINS")
  if [[ -z "$args" ]]; then
    return 0
  fi

  local first_domain
  first_domain=$(echo "$ADDITIONAL_SSL_DOMAINS" | cut -d',' -f1 | tr -d ' ')
  if ssh_sudo test -d "/etc/letsencrypt/live/$first_domain"; then
    echo "Additional cert for $first_domain already exists — skipping"
    return 0
  fi

  echo "Obtaining additional certificate for: $ADDITIONAL_SSL_DOMAINS"
  printf 'certbot certonly --standalone --non-interactive --agree-tos -m %s %s\n' \
    "$(printf '%q' "$LETSENCRYPT_EMAIL")" "$args" | ssh_sudo bash
  echo "Additional certificate obtained"
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  install_certbot)       install_certbot       ;;
  obtain_primary_cert)   obtain_primary_cert   ;;
  obtain_additional_cert) obtain_additional_cert ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
