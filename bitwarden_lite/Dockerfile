# Images are pinned by tag and multi-arch index digest. Dependabot updates
# both. When the Bitwarden lite tag changes, also bump `version` in
# config.yaml and add a CHANGELOG.md entry.

FROM docker.io/tailscale/tailscale:v1.104.7@sha256:72c1e19e0aedca96b8533bbb0b4368564410ff20b17e53b804eb6c1f04a31be4 AS tailscale
FROM docker.io/cloudflare/cloudflared:2026.11.2@sha256:55c7e3e8d89d5e8d20b75a82f3602cbf98e06db406e73e282073cfdc5a9a3af6 AS cloudflared

# Official Bitwarden lite image (multi-arch: amd64, arm64, armv7).
FROM ghcr.io/bitwarden/lite:2026.11.0@sha256:89c1844364fa6fe09e145e73b035c0e01d6194d317fb10853e30bc672a4648fb

COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscaled /usr/local/bin/
COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/
COPY rootfs/ /
RUN chmod 0755 /ha/*.sh

# Wraps the upstream /entrypoint.sh: turns the app options into the
# environment variables Bitwarden lite expects, then hands over to it.
ENTRYPOINT ["/ha/run.sh"]
