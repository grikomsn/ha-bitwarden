# Bitwarden lite

This app runs the official Bitwarden server in its
[lite deployment](https://bitwarden.com/help/install-and-deploy-lite/): one
container, SQLite, and support for ARM boards like the Home Assistant Green.
It can also publish the vault over HTTPS without opening router ports, using
either or both of:

- **Cloudflare Tunnel** on a domain or subdomain of your choice
  (`vault.example.com`).
- **Tailscale** as its own tailnet node (`vault.tail1234.ts.net`), with Serve
  for tailnet devices only, or Funnel for the public internet.

> Bitwarden's
> [standard Linux deployment](https://bitwarden.com/help/install-on-premise-linux/)
> is a set of x64-only containers with MSSQL that need 2–4 GB of RAM. It
> can't run on ARM Home Assistant hardware, so this app uses lite, which needs
> about 200 MB. Bitwarden says lite is meant for personal use and home labs.

## Before you start

1. **Installation ID and key.** Request them at <https://bitwarden.com/host/>.
   Pick the region your Bitwarden account uses (US or EU). Use a fresh pair
   for this server and keep the key secret.
2. **A hostname.** Clients need HTTPS: the web vault's cryptography doesn't
   run on plain HTTP. Pick a Cloudflare hostname, a Tailscale name, or both
   (see below). Bitwarden only works at the root of a hostname, not under a
   path like `example.com/vault`.

## Install

1. In Home Assistant go to **Settings → Apps → Install app**, open the
   three-dot menu, choose **Repositories** and add
   `https://github.com/grikomsn/ha-bitwarden`.
2. Install **Bitwarden lite**. Home Assistant downloads the prebuilt image
   (`ghcr.io/grikomsn/ha-bitwarden-lite`, signed with Cosign), which takes a
   few minutes the first time.
3. Fill in the options below, then start the app and watch the **Log** tab.

## Options

| Option | Required | Description |
| --- | --- | --- |
| `domain` | yes | Hostname clients use, without `https://`, for example `vault.example.com`. Used for links in emails, passkeys and FIDO. |
| `installation_id` / `installation_key` | yes | From <https://bitwarden.com/host/>. |
| `disable_registration` | | Turn on after creating your accounts. |
| `admin_emails` | | Addresses allowed into `/admin`. Login is by emailed link, so it needs SMTP. |
| `smtp_*` | | Outgoing mail, needed for email verification, invites, emergency access and `/admin`. `smtp_ssl` means implicit TLS (port 465). |
| `cloudflare_tunnel_token` | | Turns on the built-in Cloudflare Tunnel. |
| `tailscale`, `tailscale_auth_key`, `tailscale_hostname`, `tailscale_funnel` | | Turn on the built-in Tailscale node. |
| `env_vars` | | Any other [Bitwarden environment variable](https://bitwarden.com/help/environment-variables/), applied last. |

The vault is stored as SQLite in this app's data folder. To use MySQL/MariaDB
or PostgreSQL instead, set `BW_DB_PROVIDER`, `BW_DB_SERVER`,
`BW_DB_DATABASE`, `BW_DB_USERNAME` and `BW_DB_PASSWORD` in `env_vars`.

## Option A: Cloudflare Tunnel on your own domain

Needs a domain whose DNS is on Cloudflare.

1. In the Cloudflare dashboard open **Zero Trust → Networks → Connectors
   (Tunnels) → Create a tunnel**, choose **Cloudflared**, and name it.
2. Copy the token from the install command (the long string after
   `--token`). Skip the install step; this app runs cloudflared itself.
3. Add a **published application** (public hostname) route:
   - Subdomain and domain: whatever you want, e.g. `vault` + `example.com`.
   - Service: `HTTP` and `localhost:8080`.
   Cloudflare creates the DNS record for you.
4. In the app, set `cloudflare_tunnel_token` to the token and `domain` to the
   hostname from step 3, then (re)start the app. The log should show
   `Registered tunnel connection`.

Cloudflare settings that break Bitwarden clients on this hostname:

- **Cloudflare Access** in front of the whole hostname: the mobile and desktop
  apps can't complete the Access login. If you want Access, protect only
  `/admin`.
- **Bot Fight Mode** or WAF challenges: apps can't solve challenges. Skip the
  vault hostname in those rules.
- **WebSockets** must stay enabled (they are by default). Live sync uses
  `/notifications/hub`.

### Using the Cloudflared app instead

If you already run the community **Cloudflared** app for Home Assistant, you
can leave `cloudflare_tunnel_token` empty and add an entry to its
`additional_hosts`:

```yaml
- hostname: vault.example.com
  service: http://homeassistant:7277
```

For that, enable this app's `8080/tcp` port in **Network** and set it to the
host port you used (7277 above). Keep in mind that this also opens the vault
over plain HTTP on your LAN at that port.

## Option B: Tailscale Serve or Funnel

The app joins your tailnet as a separate machine (default name `vault`), so the
vault gets its own `https://vault.<tailnet>.ts.net` address on port 443. This is
independent of the Tailscale app you may already run for Home Assistant.

1. In the Tailscale admin console under **DNS**, enable **MagicDNS** and
   **HTTPS Certificates**.
2. For Funnel (public internet), allow it in the tailnet policy file, for
   example:

   ```json
   "nodeAttrs": [{ "target": ["autogroup:member"], "attr": ["funnel"] }]
   ```

3. In the app, turn on `tailscale` and optionally set `tailscale_hostname`
   and `tailscale_funnel`. Either paste an auth key into `tailscale_auth_key`,
   or leave it empty and open the login URL that appears in the **Log** tab.
4. In the Tailscale admin console, disable key expiry for the new machine so
   it doesn't drop off the tailnet.

If Tailscale is your only way in, set `domain` to the full name, e.g.
`vault.tail1234.ts.net`. The log prints it once the node is up.

The first Funnel request can take a few minutes while Tailscale provisions the
certificate and public DNS.

## Using both

Cloudflare and Tailscale can run at the same time. Clients can log in through
either hostname. `domain` should be the one you treat as primary: links in
emails and passkey (WebAuthn) login only work on that hostname.

## First run

1. Open `https://<domain>` and create your account.
2. Turn on `disable_registration` and restart the app.
3. In each Bitwarden app, choose **Self-hosted** on the login screen and enter
   `https://<domain>`.

## Backups and updates

- Home Assistant backups include this app's data folder: the SQLite vault,
  attachments, keys and Tailscale state. The app is stopped briefly while it is
  backed up (`backup: cold`) so SQLite is copied consistently.
- The data folder holds the vault's data-protection keys. Treat backups that
  include this app as sensitive, and set a backup password.
- The app version follows the Bitwarden lite release it is built on, with a
  fourth number for packaging-only changes (`2026.11.0.1`). Updates download
  a new prebuilt image. Release notes:
  <https://github.com/grikomsn/ha-bitwarden/releases>.

## Troubleshooting

- **App stops right after start:** the log says which required option is
  missing.
- **Logs:** the Log tab shows the API, identity, admin, notifications, icons,
  nginx, cloudflared and Tailscale login/serve logs. Tailscale's daemon logs to
  `/var/log/bitwarden/tailscaled.log` inside the container.
- **First start is slow:** the services run database migrations, so the vault
  can return errors for a minute after the app starts. The app uses roughly
  350–550 MB of RAM once running.
- **`tailscale serve failed`:** enable HTTPS certificates for the tailnet.
  **`tailscale funnel failed`:** add the `funnel` node attribute.
- **Apps say the server is unreachable through Cloudflare:** check the Access,
  Bot Fight Mode and WAF notes above.
