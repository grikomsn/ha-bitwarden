#!/bin/sh
# Stream Bitwarden's service logs and the cloudflared / Tailscale logs (all
# written to files by supervisord) to stdout, so they show in the Log tab.
# nginx/error.log is nginx's own error log (the access log is left out).
cd /var/log/bitwarden || exit 1
FILES="admin.log api.log identity.log notifications.log icons.log nginx.log nginx/error.log cloudflared.log tailscale-up.log"
for f in $FILES; do
  # Files in subfolders are created by the upstream entrypoint and nginx;
  # tail -F picks them up once they appear.
  case "$f" in */*) continue ;; esac
  [ -e "$f" ] || : > "$f"
done
# shellcheck disable=SC2086
exec tail -n 0 -F $FILES 2>/dev/null
