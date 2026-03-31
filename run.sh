#!/bin/bash
#
# Docker script to configure and start a Headscale server
#
# DO NOT RUN THIS SCRIPT ON YOUR PC OR MAC! THIS IS ONLY MEANT TO BE RUN
# IN A CONTAINER!
#
# This file is part of Headscale Docker image, available at:
# https://github.com/hwdsl2/docker-headscale
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

exiterr()  { echo "Error: $1" >&2; exit 1; }
nospaces() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
noquotes() { printf '%s' "$1" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"; }

check_ip() {
  IP_REGEX='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

check_ip6() {
  IP6_REGEX='^[0-9a-fA-F]{0,4}(:[0-9a-fA-F]{0,4}){1,7}$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IP6_REGEX"
}

check_url() {
  printf '%s' "$1" | tr -d '\n' | grep -Eq '^https?://[^[:space:]]+$'
}

check_port() {
  printf '%s' "$1" | tr -d '\n' | grep -Eq '^[0-9]+$' \
  && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

# Source bind-mounted env file if present (takes precedence over --env-file)
if [ -f /vpn.env ]; then
  # shellcheck disable=SC1091
  . /vpn.env
fi

if [ ! -f "/.dockerenv" ] && [ ! -f "/run/.containerenv" ] \
  && [ -z "$KUBERNETES_SERVICE_HOST" ] \
  && ! head -n 1 /proc/1/sched 2>/dev/null | grep -q '^run\.sh '; then
  exiterr "This script ONLY runs in a container (e.g. Docker, Podman)."
fi

# Read and sanitize environment variables
HS_SERVER_URL=$(nospaces "$HS_SERVER_URL")
HS_SERVER_URL=$(noquotes "$HS_SERVER_URL")
HS_LISTEN_PORT=$(nospaces "$HS_LISTEN_PORT")
HS_LISTEN_PORT=$(noquotes "$HS_LISTEN_PORT")
HS_METRICS_PORT=$(nospaces "$HS_METRICS_PORT")
HS_METRICS_PORT=$(noquotes "$HS_METRICS_PORT")
HS_BASE_DOMAIN=$(nospaces "$HS_BASE_DOMAIN")
HS_BASE_DOMAIN=$(noquotes "$HS_BASE_DOMAIN")
HS_LOG_LEVEL=$(nospaces "$HS_LOG_LEVEL")
HS_LOG_LEVEL=$(noquotes "$HS_LOG_LEVEL")
HS_USERNAME=$(nospaces "$HS_USERNAME")
HS_USERNAME=$(noquotes "$HS_USERNAME")
HS_DNS_SRV1=$(nospaces "$HS_DNS_SRV1")
HS_DNS_SRV1=$(noquotes "$HS_DNS_SRV1")
HS_DNS_SRV2=$(nospaces "$HS_DNS_SRV2")
HS_DNS_SRV2=$(noquotes "$HS_DNS_SRV2")

# Apply defaults
[ -z "$HS_LISTEN_PORT" ]  && HS_LISTEN_PORT="8080"
[ -z "$HS_METRICS_PORT" ] && HS_METRICS_PORT="9090"
[ -z "$HS_BASE_DOMAIN" ]  && HS_BASE_DOMAIN="headscale.internal"
[ -z "$HS_LOG_LEVEL" ]    && HS_LOG_LEVEL="info"
[ -z "$HS_USERNAME" ]     && HS_USERNAME="admin"
[ -z "$HS_DNS_SRV1" ]     && HS_DNS_SRV1="1.1.1.1"
[ -z "$HS_DNS_SRV2" ]     && HS_DNS_SRV2="1.0.0.1"

# Validate listen port
if ! check_port "$HS_LISTEN_PORT"; then
  exiterr "HS_LISTEN_PORT must be an integer between 1 and 65535."
fi

# Validate metrics port (if non-empty)
if [ -n "$HS_METRICS_PORT" ] && ! check_port "$HS_METRICS_PORT"; then
  exiterr "HS_METRICS_PORT must be an integer between 1 and 65535."
fi

# Validate log level
case "$HS_LOG_LEVEL" in
  panic|fatal|error|warn|info|debug|trace) ;;
  *) exiterr "HS_LOG_LEVEL must be one of: panic, fatal, error, warn, info, debug, trace." ;;
esac

# Sanitize username (letters, digits, hyphens, underscores only)
HS_USERNAME=$(printf '%s' "$HS_USERNAME" | \
  sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g')
if [ -z "$HS_USERNAME" ]; then
  exiterr "HS_USERNAME is invalid. Use one word only, no special characters except '-' and '_'."
fi

# Validate DNS servers
if ! check_ip "$HS_DNS_SRV1" && ! check_ip6 "$HS_DNS_SRV1"; then
  exiterr "HS_DNS_SRV1 '$HS_DNS_SRV1' is not a valid IP address."
fi
if [ -n "$HS_DNS_SRV2" ] && ! check_ip "$HS_DNS_SRV2" && ! check_ip6 "$HS_DNS_SRV2"; then
  exiterr "HS_DNS_SRV2 '$HS_DNS_SRV2' is not a valid IP address."
fi

# Determine server URL
if [ -n "$HS_SERVER_URL" ]; then
  if ! check_url "$HS_SERVER_URL"; then
    exiterr "HS_SERVER_URL '$HS_SERVER_URL' is not a valid URL (must start with http:// or https://)."
  fi
  # Strip trailing slash
  HS_SERVER_URL="${HS_SERVER_URL%/}"
else
  echo
  echo "HS_SERVER_URL not set. Trying to auto-detect public IP of this server..."
  public_ip=$(dig @resolver1.opendns.com -t A -4 myip.opendns.com +short 2>/dev/null)
  check_ip "$public_ip" || public_ip=$(wget -t 2 -T 10 -qO- http://ipv4.icanhazip.com 2>/dev/null)
  check_ip "$public_ip" || public_ip=$(wget -t 2 -T 10 -qO- http://ip1.dynupdate.no-ip.com 2>/dev/null)
  if check_ip "$public_ip"; then
    HS_SERVER_URL="http://${public_ip}:${HS_LISTEN_PORT}"
    echo "Auto-detected server URL: $HS_SERVER_URL"
    echo
    echo "  *** WARNING: Using plain HTTP. Tailscale clients require HTTPS for full   ***"
    echo "  *** functionality. Set HS_SERVER_URL to your HTTPS URL in production.     ***"
  else
    exiterr "Cannot detect public IP. Set HS_SERVER_URL in your 'env' file (e.g. https://hs.example.com)."
  fi
fi

# Ensure required directories exist
mkdir -p /etc/headscale /var/lib/headscale /var/run/headscale

echo
echo "Headscale Docker - https://github.com/hwdsl2/docker-headscale"

if ! grep -q " /var/lib/headscale " /proc/mounts 2>/dev/null; then
  echo
  echo "Note: /var/lib/headscale is not mounted. Server data (database, keys)"
  echo "      will be lost on container removal."
  echo "      Mount a Docker volume at /var/lib/headscale to persist data."
fi

# Build metrics_listen_addr value
if [ -n "$HS_METRICS_PORT" ]; then
  METRICS_ADDR="0.0.0.0:${HS_METRICS_PORT}"
else
  METRICS_ADDR=""
fi

# Build DNS nameservers list for config
DNS_NAMESERVERS="      - ${HS_DNS_SRV1}"
if [ -n "$HS_DNS_SRV2" ]; then
  DNS_NAMESERVERS="${DNS_NAMESERVERS}
      - ${HS_DNS_SRV2}"
fi

# Generate config.yaml from environment variables
# The config is (re)generated on each start so that env var changes always take effect.
cat > /etc/headscale/config.yaml <<EOF
# Headscale configuration
# Generated by docker-headscale run.sh — edit env vars to make changes.
# https://github.com/hwdsl2/docker-headscale

server_url: ${HS_SERVER_URL}
listen_addr: 0.0.0.0:${HS_LISTEN_PORT}
metrics_listen_addr: ${METRICS_ADDR}
grpc_listen_addr: 127.0.0.1:50443
grpc_allow_insecure: false

noise:
  private_key_path: /var/lib/headscale/noise_private.key

prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
  allocation: sequential

derp:
  server:
    enabled: false
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  auto_update_enabled: true
  update_frequency: 3h

disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m

database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite
    write_ahead_log: true

log:
  level: ${HS_LOG_LEVEL}
  format: text

policy:
  mode: file
  path: ""

dns:
  magic_dns: true
  base_domain: ${HS_BASE_DOMAIN}
  override_local_dns: true
  nameservers:
    global:
${DNS_NAMESERVERS}

unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"

logtail:
  enabled: false
randomize_client_port: false
EOF

INITIALIZED_MARKER="/var/lib/headscale/.initialized"

if [ ! -f "$INITIALIZED_MARKER" ]; then
  echo
  echo "Starting Headscale first-run setup..."
  echo "Server URL:   $HS_SERVER_URL"
  echo "Listen port:  $HS_LISTEN_PORT"
  echo "Base domain:  $HS_BASE_DOMAIN"
  echo "Initial user: $HS_USERNAME"
  echo "DNS servers:  ${HS_DNS_SRV1}${HS_DNS_SRV2:+, ${HS_DNS_SRV2}}"
  echo
else
  echo
  echo "Found existing Headscale data, starting server..."
  echo
fi

# Start headscale server in the background for initial setup
headscale serve -c /etc/headscale/config.yaml &
HS_PID=$!

# Wait for unix socket to become available (up to 30 seconds)
wait_for_socket() {
  local i=0
  while [ "$i" -lt 30 ]; do
    [ -S /var/run/headscale/headscale.sock ] && return 0
    sleep 1
    i=$((i + 1))
  done
  return 1
}

if ! wait_for_socket; then
  echo "Error: Headscale failed to start (unix socket not created after 30s)." >&2
  kill "$HS_PID" 2>/dev/null
  exit 1
fi

# First-run: create initial user and pre-auth key
if [ ! -f "$INITIALIZED_MARKER" ]; then
  echo "Creating user '$HS_USERNAME'..."
  headscale -c /etc/headscale/config.yaml users create "$HS_USERNAME" 2>&1 || true

  # Look up the numeric user ID (required by preauthkeys create)
  HS_USER_ID=$(headscale -c /etc/headscale/config.yaml users list \
    --name "$HS_USERNAME" -o json 2>/dev/null | \
    tr -d ' \n\t' | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

  echo
  echo "==========================================================="
  echo " Initial pre-auth key"
  if [ -n "$HS_USER_ID" ]; then
    echo " (user: $HS_USERNAME, reusable, expires in 24 hours)"
  else
    echo " (reusable, expires in 24 hours)"
  fi
  echo "==========================================================="
  if [ -n "$HS_USER_ID" ]; then
    headscale -c /etc/headscale/config.yaml preauthkeys create \
      --user "$HS_USER_ID" \
      --reusable \
      --expiration 24h 2>&1 || true
  else
    # --user is optional in headscale v0.28+; create key without user association
    headscale -c /etc/headscale/config.yaml preauthkeys create \
      --reusable \
      --expiration 24h 2>&1 || true
  fi
  echo "==========================================================="
  echo
  echo "To connect a Tailscale client to this server, run:"
  echo "  tailscale up --login-server $HS_SERVER_URL --authkey <key-above>"
  echo
  echo "To create more pre-auth keys:"
  echo "  docker exec <container> hs_manage --createkey --user $HS_USERNAME"
  echo
  echo "Setup complete."
  echo

  touch "$INITIALIZED_MARKER"
fi

# Graceful shutdown handler
cleanup() {
  echo
  echo "Stopping Headscale..."
  kill "$HS_PID" 2>/dev/null
  wait "$HS_PID" 2>/dev/null
  exit 0
}
trap cleanup INT TERM

# Wait for headscale to exit
wait "$HS_PID"