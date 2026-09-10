# HeavyBlue Nest

Static homepage (`public/`) for heavybluewoodpecker.com / .net.

## Origin deploy (this server)

See **[docs/ORIGIN_SETUP.md](docs/ORIGIN_SETUP.md)** for the full nginx + Cloudflare Tunnel record,
including log permission troubleshooting and local verification.

```bash
./scripts/deploy-origin.sh
```

On the origin host, after bashrc load:

```bash
hbw-setup status
hbw-setup show    # full setup record
```

### Quick origin checks

```bash
sudo systemctl status nginx
sudo nginx -t
curl -sI -H 'Host: heavybluewoodpecker.com' http://127.0.0.1/
```

**Do not** run bare `nginx` as a normal user — that fails with
`Permission denied` on `/var/log/nginx/error.log`. Use `sudo systemctl`
or `sudo nginx -t` / `sudo systemctl reload nginx` instead. Details in
[docs/ORIGIN_SETUP.md](docs/ORIGIN_SETUP.md#nginx-log-permission-error).
