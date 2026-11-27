# Infisical (secrets)

Secrets manager for the homelab. Every secret referenced in these docs as `infisical:/…` lives here.

| | |
|---|---|
| Compose | `dokploy/compose-files/projects/homelab/infisical/compose.yml` |
| Dokploy app | Compose · `homelab-infisical-kfplct` |
| Node | `docker-dev-1` |
| Images | `infisical/infisical:v0.135.0-postgres`, `postgres:14-alpine`, `redis:7-alpine` |
| URLs | `https://infisical.homelab.capilabs.dev` (public, tunnel), `https://infisical.home.capilabs.dev` (local) |
| Host port | `9003` → `8080` |
| Data | binds `/mnt/docker-storage/infisical/pg_data`, `/mnt/docker-storage/infisical/redis_data` |
| Config | `.env` from `.env.sample` (`ENCRYPTION_KEY`, `AUTH_SECRET`, DB and Redis credentials, `SITE_URL`) |

The Traefik labels here are the reference dual-router pattern (public `web` router + local
`websecure` router with the `cloudflare` cert resolver), see
[Dokploy / Swarm](../platforms/dokploy-swarm.md).

TODO: `ENCRYPTION_KEY` and `AUTH_SECRET` can't be stored in Infisical itself. Record where the
offline copy is kept.

TODO: document how apps pull their secrets from Infisical (env injection vs. CLI vs. Dokploy env).
