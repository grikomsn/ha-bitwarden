ARG BITWARDEN_VERSION=2026.11.0
ARG TAILSCALE_VERSION=v1.104.7
ARG CLOUDFLARED_VERSION=2026.11.0

FROM docker.io/tailscale/tailscale:${TAILSCALE_VERSION} AS tailscale
FROM docker.io/cloudflare/cloudflared:${CLOUDFLARED_VERSION} AS cloudflared

# Official Bitwarden lite image (multi-arch: amd64, arm64, armv7).
FROM ghcr.io/bitwarden/lite:${BITWARDEN_VERSION}

COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscaled /usr/local/bin/
COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/
COPY rootfs/ /
RUN chmod 0755 /ha/*.sh

# Wraps the upstream /entrypoint.sh: turns the app options into the
# environment variables Bitwarden lite expects, then hands over to it.
ENTRYPOINT ["/ha/run.sh"]
