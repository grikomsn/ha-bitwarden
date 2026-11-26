<img src="assets/icon.svg" width="64" height="64" alt="">

# ha-bitwarden

A Home Assistant app repository for self-hosting the **official Bitwarden
server** (lite deployment) on Home Assistant OS, with optional:

- **Cloudflare Tunnel** to serve it on your own domain or subdomain, and
- **Tailscale Serve/Funnel** to serve it on your tailnet or the internet.

No router ports need to be opened for either.

## Install

[![Add repository to Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fgrikomsn%2Fha-bitwarden)

Or add `https://github.com/grikomsn/ha-bitwarden` under **Settings → Apps →
Install app → ⋮ → Repositories**, then install **Bitwarden lite**.

## Apps

| App | Description |
| --- | --- |
| [Bitwarden lite](bitwarden_lite/) | Bitwarden lite 2026.11.0 with built-in cloudflared and Tailscale. [Docs](bitwarden_lite/DOCS.md) |

## How it fits together

```text
Bitwarden apps ──HTTPS──> Cloudflare edge ──tunnel──> cloudflared ─┐
                                                                   ├─> nginx :8080 ─> Bitwarden services ─> SQLite
Tailnet devices ─HTTPS──> Tailscale Serve (vault.<tailnet>.ts.net)┘   (all inside one app container)
```

The app's Dockerfile starts from `ghcr.io/bitwarden/lite`, adds the
`tailscale` and `cloudflared` binaries from their official images, and wraps the
upstream entrypoint with [`run.sh`](bitwarden_lite/rootfs/ha/run.sh), which
turns the app's options into Bitwarden's environment variables.

## Releases

Versions follow Bitwarden lite (`2026.11.0`), with a fourth number for
packaging-only changes (`2026.11.0.1`). Each release publishes Cosign-signed
`amd64`/`aarch64` images to `ghcr.io/grikomsn/ha-bitwarden-lite` and a
[GitHub release](https://github.com/grikomsn/ha-bitwarden/releases).
Dependencies are kept current by Renovate. See [RELEASING.md](RELEASING.md).

## Status

Running on a Home Assistant Green (aarch64), reached through both a
Cloudflare Tunnel and Tailscale Serve. Every release is also built for amd64
and aarch64 in CI and smoke-tested on amd64. Feedback and issues are welcome.

## Why Bitwarden lite and not Vaultwarden?

The community [Vaultwarden app](https://github.com/hassio-addons/app-vaultwarden)
is a lighter, unofficial reimplementation of the Bitwarden API. This repository
runs Bitwarden's own server code instead. Bitwarden's standard self-hosted
deployment is x64-only and needs 2–4 GB of RAM, so lite is the variant that
fits on Home Assistant hardware.

## License and trademarks

The packaging in this repository (Dockerfile, scripts, configuration and docs)
is [MIT licensed](LICENSE). The image it builds contains Bitwarden lite, whose
server code is under Bitwarden's own licenses, plus Tailscale (BSD-3-Clause)
and cloudflared (Apache-2.0).

This is an unofficial community project. It is not affiliated with or endorsed
by Bitwarden, Inc., Tailscale Inc., Cloudflare, Inc. or the Home Assistant
project. "Bitwarden" is a trademark of Bitwarden, Inc.

Security issues: see [SECURITY.md](SECURITY.md).
