# Changelog

## 2026.11.0.1

- Fix the `could not open error log file ... Permission denied` alert nginx
  logged on every start.
- Show nginx's error log in the Log tab.
- Installs and updates now download a signed, prebuilt image from
  `ghcr.io/grikomsn/ha-bitwarden-lite` instead of building on the device.
- Installs built on the device from an earlier 2026.11.0 also move to
  cloudflared 2026.11.2.

## 2026.11.0

- First release, based on Bitwarden lite 2026.11.0.
- Built-in cloudflared 2026.11.2 (Cloudflare Tunnel, token mode).
- Built-in Tailscale v1.104.7 (separate node, Serve or Funnel).
- Base images pinned by digest.
