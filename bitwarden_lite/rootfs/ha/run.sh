#!/bin/sh
# Home Assistant wrapper for the official Bitwarden lite image.
#
# Reads the app options written by the Supervisor, exports the environment
# variables documented at https://bitwarden.com/help/install-and-deploy-lite/,
# registers optional cloudflared / Tailscale programs with the image's
# supervisord, then execs the upstream /entrypoint.sh unchanged.
set -eu

OPTIONS=/etc/bitwarden/options.json
SUPERVISOR_DIR=/etc/supervisor.d
RUN_DIR=/tmp/bitwarden

log() { echo "[ha-bitwarden] $*"; }
die() { echo "[ha-bitwarden] ERROR: $*" >&2; exit 1; }

# opt NAME -> value as text; empty when unset or null. Booleans print true/false.
opt() {
  jq -r --arg k "$1" 'if has($k) and .[$k] != null then .[$k] | tostring else "" end' "$OPTIONS"
}

[ -f "$OPTIONS" ] || die "$OPTIONS not found. Is /etc/bitwarden mapped to the app data folder?"

# --- Required settings -------------------------------------------------------
domain="$(opt domain | sed -E 's#^[A-Za-z]+://##; s#[/:].*$##')"
installation_id="$(opt installation_id)"
installation_key="$(opt installation_key)"

[ -n "$domain" ] || die "Set the 'domain' option to the hostname clients will use, e.g. vault.example.com or vault.tail1234.ts.net."
[ -n "$installation_id" ] || die "Set 'installation_id' (request one at https://bitwarden.com/host/)."
[ -n "$installation_key" ] || die "Set 'installation_key' (request one at https://bitwarden.com/host/)."
case "$installation_id" in
  00000000-0000-0000-0000-000000000000)
    die "'installation_id' is the all-zero placeholder. Use the ID from https://bitwarden.com/host/." ;;
  ????????-????-????-????-????????????) ;;
  *) die "'installation_id' should look like xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (from https://bitwarden.com/host/)." ;;
esac

export BW_DOMAIN="$domain"
export BW_INSTALLATION_ID="$installation_id"
export BW_INSTALLATION_KEY="$installation_key"

# --- Fixed choices for running inside Home Assistant -------------------------
# SQLite in /etc/bitwarden (the app data folder). TLS is terminated by
# Cloudflare or Tailscale in front of nginx, so nginx serves plain HTTP on 8080.
export BW_DB_PROVIDER=sqlite
export BW_ENABLE_SSL=false
export BW_PORT_HTTP=8080
# Home Assistant backs up the data folder; lite's own backup job would need a
# separate /backups mount.
export BACKUP_DB=0
# cloudflared and Tailscale Serve connect from localhost and set X-Forwarded-For.
export BW_REAL_IPS="127.0.0.1,::1"
# Workstation GC keeps the .NET services' memory use down on small boards.
export DOTNET_gcServer=0
export DOTNET_GCConserveMemory=5

disable_registration="$(opt disable_registration)"
export globalSettings__disableUserRegistration="${disable_registration:-false}"

admins="$(jq -r '(.admin_emails // []) | join(",")' "$OPTIONS")"
if [ -n "$admins" ]; then
  export adminSettings__admins="$admins"
fi

# --- SMTP (optional) ---------------------------------------------------------
smtp_host="$(opt smtp_host)"
if [ -n "$smtp_host" ]; then
  smtp_port="$(opt smtp_port)"
  smtp_ssl="$(opt smtp_ssl)"
  smtp_reply_to="$(opt smtp_reply_to)"
  export globalSettings__mail__smtp__host="$smtp_host"
  export globalSettings__mail__smtp__port="${smtp_port:-587}"
  export globalSettings__mail__smtp__ssl="${smtp_ssl:-false}"
  export globalSettings__mail__replyToEmail="${smtp_reply_to:-no-reply@$domain}"
  smtp_username="$(opt smtp_username)"
  smtp_password="$(opt smtp_password)"
  if [ -n "$smtp_username" ]; then
    export globalSettings__mail__smtp__username="$smtp_username"
    export globalSettings__mail__smtp__password="$smtp_password"
  fi
  log "SMTP: $smtp_host:${smtp_port:-587}"
else
  log "SMTP not configured: email verification, invites and the /admin portal login will not work."
fi

# --- Extra environment variables (applied last, so they override) ------------
count="$(jq '(.env_vars // []) | length' "$OPTIONS")"
i=0
while [ "$i" -lt "$count" ]; do
  name="$(jq -r ".env_vars[$i].name" "$OPTIONS")"
  value="$(jq -r ".env_vars[$i].value" "$OPTIONS")"
  case "$name" in
    "" | [0-9]* | *[!A-Za-z0-9_]*) die "env_vars: invalid variable name '$name'" ;;
  esac
  export "$name=$value"
  log "env_vars: set $name"
  i=$((i + 1))
done

# --- Optional sidecar programs -----------------------------------------------
mkdir -p "$RUN_DIR"
rm -f "$SUPERVISOR_DIR"/ha-*.ini "$RUN_DIR"/cloudflared.token "$RUN_DIR"/tailscale.authkey

tunnel_token="$(opt cloudflare_tunnel_token)"
if [ -n "$tunnel_token" ]; then
  umask 077
  printf '%s' "$tunnel_token" > "$RUN_DIR/cloudflared.token"
  umask 022
  cat > "$SUPERVISOR_DIR/ha-cloudflared.ini" <<'EOF'
[program:ha-cloudflared]
command=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token-file /tmp/bitwarden/cloudflared.token
environment=HOME="/tmp/bitwarden"
autostart=true
autorestart=true
priority=20
startsecs=10
; Keep retrying (with growing back-off) if the network isn't up yet at boot.
startretries=30
redirect_stderr=true
stdout_logfile=/var/log/bitwarden/cloudflared.log
stdout_logfile_maxbytes=10485760
stdout_logfile_backups=2
EOF
  log "Cloudflare Tunnel: enabled (point the tunnel's public hostname at http://localhost:8080)"
else
  log "Cloudflare Tunnel: disabled"
fi

if [ "$(opt tailscale)" = "true" ]; then
  mkdir -p /etc/bitwarden/tailscale
  ts_auth_key="$(opt tailscale_auth_key)"
  if [ -n "$ts_auth_key" ]; then
    umask 077
    printf '%s' "$ts_auth_key" > "$RUN_DIR/tailscale.authkey"
    umask 022
  fi
  ts_hostname="$(opt tailscale_hostname)"
  ts_funnel="$(opt tailscale_funnel)"
  cat > "$SUPERVISOR_DIR/ha-tailscale.ini" <<EOF
[program:ha-tailscaled]
command=/usr/local/bin/tailscaled --tun=userspace-networking --statedir=/etc/bitwarden/tailscale --socket=/tmp/bitwarden/tailscaled.sock
autostart=true
autorestart=true
priority=10
startsecs=5
redirect_stderr=true
stdout_logfile=/var/log/bitwarden/tailscaled.log
stdout_logfile_maxbytes=10485760
stdout_logfile_backups=2

[program:ha-tailscale-up]
command=/ha/tailscale-up.sh
environment=TS_HOSTNAME="${ts_hostname:-vault}",TS_FUNNEL="${ts_funnel:-false}"
autostart=true
autorestart=unexpected
exitcodes=0
priority=30
startsecs=0
redirect_stderr=true
stdout_logfile=/var/log/bitwarden/tailscale-up.log
stdout_logfile_maxbytes=1048576
stdout_logfile_backups=1
EOF
  log "Tailscale: enabled as '${ts_hostname:-vault}' (funnel: ${ts_funnel:-false})"
else
  log "Tailscale: disabled"
fi

# supervisord drops to an unprivileged user that can't reopen the container's
# stdout, so programs log to files and this follower, started here as root with
# stdout inherited, streams them to the app's Log tab.
/ha/follow-logs.sh &

log "Starting Bitwarden lite for https://$BW_DOMAIN"
exec /entrypoint.sh
