# HeavyBlue Nest — origin / reverse-proxy setup record

Recorded: 2026-08-27 (local host `InternetThief`)  
Purpose: durable notes for nginx + Cloudflare Tunnel origin serving this repo’s `public/` assets.

## Domains

| Domain | Role |
|--------|------|
| `heavybluewoodpecker.com` | Primary web origin (Cloudflare zone active) |
| `www.heavybluewoodpecker.com` | Same origin via tunnel |
| `heavybluewoodpecker.net` | Same static site via tunnel (mail MX/SPF/DKIM left on Cloudflare Email Routing) |
| `www.heavybluewoodpecker.net` | Same origin via tunnel |

## Architecture

```
Browser
  → Cloudflare edge (HTTPS, orange-cloud)
  → Cloudflare Tunnel (cloudflared connector on origin)
  → nginx on 127.0.0.1:80
  → static files in /var/www/heavybluewoodpecker  (rsync from repo public/)
```

No router port-forward required. Residential Xfinity gateway blocked inbound 80/443 (UPnP unavailable); tunnel fixed HTTP 523.

## This machine

| Item | Value |
|------|--------|
| Hostname | `InternetThief.heavybluewoodpecker.com` |
| LAN | `10.0.0.29/24` via `10.0.0.1` (Xfinity) |
| Public IP (egress) | `68.45.21.146` |
| OS | Debian / MX Linux |
| Site clone | `~/sites/heavyblue-nest` |
| GitHub | `https://github.com/heavybluewoodpecker/heavyblue-nest` |

## nginx

| Item | Path / value |
|------|----------------|
| Package | `nginx` (systemd `nginx.service`, enabled) |
| Site config | `/etc/nginx/sites-available/heavybluewoodpecker.com` |
| Enabled | `/etc/nginx/sites-enabled/heavybluewoodpecker.com` |
| Docroot | `/var/www/heavybluewoodpecker` |
| Health | `GET /nginx-health` → `ok` |
| Listen | `:80` and `:443` (tunnel uses HTTP to `:80`) |
| Real IP | `/etc/nginx/conf.d/cloudflare-realip.conf` (`CF-Connecting-IP`) |
| Origin CA cert | `/etc/ssl/cloudflare/heavybluewoodpecker.com.pem` |
| Origin CA key | `/etc/ssl/cloudflare/heavybluewoodpecker.com.key` |
| UFW | `80/tcp`, `443/tcp` allowed (still unused while on tunnel-only) |

`server_name` includes `.com` and `.net` apex + www.

## Cloudflare Tunnel

| Item | Value |
|------|--------|
| Binary | `cloudflared` 2026.8.2 |
| Service | `cloudflared.service` (enabled, active) |
| Tunnel name | `hbw-origin` |
| Tunnel ID | `b5c17caa-dbdd-4766-9910-761abf67bf50` |
| DNS target | `b5c17caa-dbdd-4766-9910-761abf67bf50.cfargotunnel.com` |
| Ingress | hostnames above → `http://127.0.0.1:80` |
| Token file | managed under `/etc/cloudflared/` (do not commit) |

### Cloudflare zone IDs (account Goffster2025@gmail.com)

| Zone | Zone ID |
|------|---------|
| heavybluewoodpecker.com | `7e6bc4f05eae7ebd61428128cbe02ef0` |
| heavybluewoodpecker.net | `c033ccf0c4e53bbaf41e2c8143c4a7fd` |
| Account ID | `5045a1ec5df85b7c04191d62f7aecb58` |

### DNS pattern (both zones)

- Apex / `www` / `*` → CNAME → `<tunnel-id>.cfargotunnel.com` (proxied)
- SSL mode: **Full** (Origin CA on nginx; tunnel path is HTTP to origin locally)
- Always Use HTTPS: on
- `.net` mail records (MX/TXT) preserved

**Do not store API tokens in git.** Use Cloudflare dashboard or env `CF_API_TOKEN` only in shell memory/secret store.

## Deploy workflow (this repo)

```bash
cd ~/sites/heavyblue-nest
./scripts/deploy-origin.sh           # git pull + rsync public/ + nginx reload
./scripts/deploy-origin.sh --no-pull # rsync only
npm run deploy:origin
```

| Item | Value |
|------|--------|
| Script | `scripts/deploy-origin.sh` |
| npm script | `deploy:origin` |
| Source | `public/` |
| Destination | `/var/www/heavybluewoodpecker/` |
| Provenance | `/var/www/heavybluewoodpecker/.deployed-from` |
| Commit that added script | `9470cb7` on `main` |

## Verification

```bash
curl -sS https://heavybluewoodpecker.com/nginx-health
curl -sS https://heavybluewoodpecker.net/nginx-health
curl -sS https://heavybluewoodpecker.com/ | head
systemctl is-active nginx cloudflared
```

Expect health `ok` and homepage **HeavyBlue Nest** HTML.

## Incident history (short)

1. Fresh host: no prior nginx/letsencrypt remnants; bash history began with Warp install.
2. Domain on Cloudflare returned **523** (origin unreachable).
3. nginx + Origin CA installed; DNS A pointed at `68.45.21.146`.
4. Xfinity router: no UPnP; ports 80/443 not reachable from WAN.
5. Cloudflare Tunnel installed → 523 cleared for `.com` and `.net`.
6. Static test page, then deploy from git `public/`.
7. `scripts/deploy-origin.sh` committed and pushed.

## Related paths on disk

```
~/sites/heavyblue-nest/          # git clone
/var/www/heavybluewoodpecker/    # live docroot
/etc/nginx/sites-available/heavybluewoodpecker.com
/etc/ssl/cloudflare/
/etc/cloudflared/
~/.local/share/heavybluewoodpecker/setup-record.md   # copy of this record for shell
~/.local/bin/hbw-setup           # bash helper
```

## Security notes

- Rotate any Cloudflare API token that was pasted into chat/logs.
- Origin CA private key must stay root-readable only.
- Tunnel token is equivalent to connector credential — treat as secret.

## nginx log permission error

### Symptom (2026-09-10)

Running bare `nginx` as a normal user failed with:

```text
the "user" directive makes sense only if the master process runs with super-user privileges, ignored
open() "/var/log/nginx/error.log" failed (13: Permission denied)
```

### Cause

System nginx starts the **master process as root** (via systemd). An
unprivileged `nginx` invocation cannot open `/var/log/nginx/error.log`,
honor `user www-data;`, bind port 80, or write `/run/nginx.pid`.

This is expected — not a broken install.

### Correct operations

```bash
sudo nginx -t                 # validate config
sudo systemctl start nginx    # start if stopped
sudo systemctl reload nginx   # apply config changes
sudo systemctl status nginx   # health
```

Do **not** run plain `nginx` as your login user. Prefer
`./scripts/deploy-origin.sh`, which already uses `sudo nginx -t` and
`systemctl reload`.

### Expected log ownership

Do not make logs world-writable. Keep daemon ownership:

```text
/var/log/nginx/                                 root:adm     755
/var/log/nginx/access.log                       www-data:adm 640
/var/log/nginx/error.log                        www-data:adm 640
/var/log/nginx/heavybluewoodpecker.access.log   root:adm     640
/var/log/nginx/heavybluewoodpecker.error.log    root:adm     640
```

Normalize if needed:

```bash
sudo chown root:adm /var/log/nginx
sudo chmod 755 /var/log/nginx
sudo chown www-data:adm /var/log/nginx/access.log /var/log/nginx/error.log
sudo chmod 640 /var/log/nginx/access.log /var/log/nginx/error.log
sudo chown root:adm /var/log/nginx/heavybluewoodpecker.access.log \
                    /var/log/nginx/heavybluewoodpecker.error.log
sudo chmod 640 /var/log/nginx/heavybluewoodpecker.*.log
sudo nginx -t && sudo systemctl reload nginx
```

Group `adm` may read logs; only root/systemd should start nginx.

## Local verification (2026-09-10)

On origin host `InternetThief` (Ubuntu):

```bash
curl -sI -H 'Host: heavybluewoodpecker.com' http://127.0.0.1/
curl -sI -H 'Host: www.heavybluewoodpecker.com' http://127.0.0.1/
systemctl is-active nginx
sudo nginx -t
```

**Results**

- Apex and `www` Host headers → `HTTP/1.1 200 OK`, `Content-Type: text/html`
- `nginx.service` → `active (running)`
- `sudo nginx -t` → successful
- Headers include `X-Content-Type-Options: nosniff` and
  `Referrer-Policy: strict-origin-when-cross-origin`

Docroot at verification time also carried operator notes under
`/var/www/heavybluewoodpecker/README.md` (not part of `public/` deploy;
prefer this git doc as source of truth).
