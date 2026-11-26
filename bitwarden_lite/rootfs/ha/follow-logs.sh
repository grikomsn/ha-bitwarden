#!/bin/sh
# Stream Bitwarden's service logs and the cloudflared / Tailscale logs (all
# written to files by supervisord) to stdout, so they show in the Log tab.
cd /var/log/bitwarden || exit 1
FILES="admin.log api.log identity.log notifications.log icons.log nginx.log cloudflared.log tailscale-up.log"
for f in $FILES; do
  [ -e "$f" ] || : > "$f"
done
# shellcheck disable=SC2086
exec tail -n 0 -F $FILES 2>/dev/null
