# Images are pinned by tag and multi-arch index digest; Renovate updates both
# (and `version` in config.yaml with the Bitwarden lite tag). Any change here
# needs a version bump and a CHANGELOG.md entry: see RELEASING.md.

FROM docker.io/tailscale/tailscale:v1.104.7@sha256:72c1e19e0aedca96b8533bbb0b4368564410ff20b17e53b804eb6c1f04a31be4 AS tailscale
FROM docker.io/cloudflare/cloudflared:2026.11.2@sha256:55c7e3e8d89d5e8d20b75a82f3602cbf98e06db406e73e282073cfdc5a9a3af6 AS cloudflared

# Official Bitwarden lite image (multi-arch: amd64, arm64, armv7).
FROM ghcr.io/bitwarden/lite:2026.11.0@sha256:89c1844364fa6fe09e145e73b035c0e01d6194d317fb10853e30bc672a4648fb

COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscaled /usr/local/bin/
COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/
COPY rootfs/ /
RUN chmod 0755 /ha/*.sh

# Upstream starts nginx as an unprivileged user without -e, so before reading
# nginx.conf it tries the compiled-in error log under /var/lib/nginx and logs
# "Permission denied" on every start. Point it at the error log nginx.conf
# already uses. The grep fails the build if upstream changes that line.
RUN sed -i 's#^command=nginx$#command=nginx -e /var/log/bitwarden/nginx/error.log#' /etc/supervisor.d/nginx.ini \
  && grep -qx 'command=nginx -e /var/log/bitwarden/nginx/error.log' /etc/supervisor.d/nginx.ini

# Wraps the upstream /entrypoint.sh: turns the app options into the
# environment variables Bitwarden lite expects, then hands over to it.
ENTRYPOINT ["/ha/run.sh"]
