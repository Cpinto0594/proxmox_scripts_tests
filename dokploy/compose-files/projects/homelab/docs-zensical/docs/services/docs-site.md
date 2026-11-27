# Docs site (Zensical)

This site. Built from `docs-zensical/` in this repo.

| | |
|---|---|
| Compose | `dokploy/compose-files/projects/homelab/docs-zensical/compose.yaml` |
| Dokploy app | Compose · `homelab-zensical-l9cgdm` (plain Compose: `docker stack deploy` can't `build:`) |
| Node | `docker-dev-1` |
| Image | `homelab-docs:latest`, built from the `Dockerfile` on every deploy |
| URL | `https://docs.home.capilabs.dev` (local and Tailscale only) |
| Source | this repo on Forgejo, Dokploy autodeploy on push |

No public router on purpose: the docs contain topology and internal IPs. `.env.sample` still has a
`PUBLIC_DOMAIN`, but nothing uses it.

## Edit and preview

Pages are in `docs/`, the sidebar is the `nav` in `zensical.toml`. A new page only shows up in the
menu once it's in `nav`.

```bash
cd dokploy/compose-files/projects/homelab/docs-zensical
pip install zensical
zensical serve   # http://localhost:8000
```
