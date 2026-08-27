# HeavyBlue Nest

Static homepage (`public/`) for heavybluewoodpecker.com / .net.

## Origin deploy (this server)

See **[docs/ORIGIN_SETUP.md](docs/ORIGIN_SETUP.md)** for the full nginx + Cloudflare Tunnel record.

```bash
./scripts/deploy-origin.sh
```

On the origin host, after bashrc load:

```bash
hbw-setup status
hbw-setup show    # full setup record
```
