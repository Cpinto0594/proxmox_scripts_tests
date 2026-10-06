# Service catalog

One row per running service. Add a dedicated page (`services/<name>.md`) when a service has enough config or history to need one.

| Service | Where | Deploy type | URL / port | Data | Notes |
|---|---|---|---|---|---|
| Dokploy | `docker-dev-1` | Native | TODO | | Manages the Swarm stack |
| Traefik | `docker-dev-1` | Dokploy-managed | `dokploy-traefik:80` | | Entry for tunnel traffic |
| cloudflared | `docker-dev-1` | Dokploy Compose | — | | Cloudflare Tunnel |
| Portainer | `docker-dev-1` | Dokploy Compose | TODO | | Via Dokploy, not standalone |
| Forgejo | `docker-dev-1` | Dokploy Swarm (`homelab-forgeo-qf46av`) | `forgejo.homelab.capilabs.dev`, SSH `:2222` | Postgres + Redis | Replaced GitLab. Admin creds in Infisical |
| Forgejo runner (`docker-runner1`) | TODO | Plain Docker Compose | — | | `code.forgejo.org/forgejo/runner`, docker.sock |
| Infisical | `docker-dev-1` | Dokploy Compose (plain) | backend `:9003` | `/mnt/docker-storage/infisical` | Secrets manager; reference label pattern |
| Home Assistant | `docker-worker-1` | Dokploy Swarm | `homeassistant.homelab.capilabs.dev`, `192.168.40.11:9004` | TODO | Tapo plug dashboards |
| Beszel | `docker-worker-1` | Dokploy Swarm | TODO | | Monitoring |
| Dozzle | Global (all Swarm nodes) | Dokploy Swarm (`homelab-dozzle-787xfy`) | TODO | | Log viewer, swarm mode |
| Frigate | `docker-dev-1` | Docker | TODO | Named volume → planned `/mnt/frigate-storage` | 5× Tapo C200 via RTSP |
| tenant-os | `docker-dev-1` | TODO | TODO | `tenant-os-tenants-db-server`, `tenant-os-registrar-db-server` | |
| Technitium DNS | → dedicated LXC | Native (migrating from Compose) | `192.168.10.2` | | |
| Headlamp | Kubernetes | Terragrunt | TODO | | Unreachable via Tailscale on mobile |

## Planned

| Service | Where | Notes |
|---|---|---|
| Pterodactyl Panel | `docker-worker-1`, Dokploy | MariaDB + Redis, `pterodactyl.homelab.capilabs.dev` |
| Pterodactyl Wings | Dedicated node, plain Compose | Needs host net, privileged, docker.sock |
| Databasus | Dokploy | Was set up for `prod-postgres` (since removed) — TODO: re-point at current DBs or drop |
| PostgreSQL HA (Patroni + etcd) | 3 VMs, VLAN 40 | Learning lab |
| MariaDB Galera + MaxScale | 3 VMs | Learning lab, latest stable MariaDB |

## Retired

| Service | Replaced by / reason |
|---|---|
| GitLab CE + registry | Forgejo ([ADR-0002](../decisions/0002-forgejo-over-gitlab.md)) |
| `prod-postgres`, `prod-postgres-lite` | Removed from `docker-dev-1` |
