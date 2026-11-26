# Security policy

This repository packages the official Bitwarden lite server as a Home
Assistant app. It holds password vaults, so please report security problems
privately.

## What to report here

Problems in this repository's own code: the [Dockerfile](bitwarden_lite/Dockerfile),
the wrapper scripts in [`bitwarden_lite/rootfs/ha/`](bitwarden_lite/rootfs/ha/),
and the app configuration. For example, secrets leaking into logs, wrong file
permissions, or Tailscale or Cloudflare settings that expose more than intended.

Report them through
[GitHub private vulnerability reporting](https://github.com/grikomsn/ha-bitwarden/security/advisories/new).
Please don't open a public issue.

## What to report upstream

- Bitwarden server, web vault or clients: <https://bitwarden.com/help/security/>
  (Bitwarden runs a bug bounty on HackerOne).
- Tailscale: <https://tailscale.com/security>
- cloudflared: <https://www.cloudflare.com/disclosure/>

## Supported versions

Only the latest release of the app gets fixes. It tracks the latest Bitwarden
lite release.
