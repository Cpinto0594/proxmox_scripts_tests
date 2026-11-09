# Service catalog

Everything running on the Docker nodes, from `docker ps`, `docker inspect` and `docker service ls` (captured 2026-10-06). Add a dedicated page (`services/<name>.md`) when a service needs one.

**Reachability:** *Domains* go through Traefik — `*.homelab.capilabs.dev` via Cloudflare Tunnel (internet), `*.home.capilabs.dev` via Technitium (LAN + Tailscale). *Host ports* are published on all of the node's interfaces: reachable from the LAN and over Tailscale, **not** from the internet (nothing is port-forwarded on the router). Swarm ingress ports (`*:port`) answer on every Swarm node.

## Platform

| Service | Node | Deploy | Version | Domains | Host ports | Data |
|---|---|---|---|---|---|---|
| Dokploy | `docker-dev-1` | Swarm service (Dokploy-managed) | v0.30.7 | — | 3000 | `/etc/dokploy`, volume `dokploy` |
| Dokploy Postgres | `docker-dev-1` | Swarm service (Dokploy-managed) | Postgres 16 | — | — | volume `dokploy-postgres` |
| Traefik (`dokploy-traefik`) | `docker-dev-1` | Container (Dokploy-managed) | v3.6.25 | — | 80, 443 (tcp+udp) | `/etc/dokploy/traefik/` (`traefik.yml`, `dynamic/`) |
| cloudflared | `docker-dev-1` | Compose · `local-infra-cloudflare-tunnel-e0cbqi` | `latest` | — | — | — |

## Homelab apps

| Service | Node | Deploy · stack | Version | Domains | Host ports | Data (volumes) | Notes |
|---|---|---|---|---|---|---|---|
| Forgejo | `docker-worker-1` | Swarm · `homelab-forgejo-rgu8rl` | 10 | `forgejo.homelab…`, `forgejo.home…` | — | `forgejo-data`, `forgejo-db-data` (Postgres 16), `forgejo-redis-data` (Redis 7) | Admin user `configmin` |
| Forgejo runner | `docker-worker-1` | Swarm · `homelab-forgejo-runner1-a28nkd` | 12.9.0 | — | — | `forgejo-runner1` | Mounts `docker.sock` |
| Infisical | `docker-dev-1` | Compose · `homelab-infisical-kfplct` | v0.135.0 | `infisical.homelab…`, `infisical.home…` | 9003 | `infisical-pg-data` (Postgres 14), `infisical-redis-data` (Redis 7) | Reference dual-router label pattern |
| Portainer | `docker-dev-1` | Compose · `homelab-portainer-ydf7mb` | `latest` | `portainer.homelab…`, `portainer.home…` | 8000, 9001 | `portainer_data` | Mounts `docker.sock` |
| Databasus | `docker-dev-1` | Compose · `homelab-databasus-kd3hwx` | `latest` | `databasus.homelab…`, `databasus.home…` | 9002 | `databasus_data` | Backs up the tenant-os Postgres DBs |
| Beszel hub | `docker-worker-1` | Swarm · `homelab-beszel-eynrop` | 0.19.0 | `beszel.homelab…`, `beszel.home…` | — | `beszel_hub_data` | Monitoring dashboard |
| Beszel agents | both nodes | Swarm · `homelab-beszel-eynrop` | 0.19.0 | — | — | `beszel_agent_data`, `…_dev1` | One service per node (`beszel-agent`, `beszel-agent-dev1`) |
| Dozzle | both nodes (global, 2/2) | Swarm · `homelab-dozzle-8apzz5` | `latest` | `dozzle.homelab…`, `dozzle.home…` | — | `dozzle-data` | Log viewer, swarm mode |
| Docs site | `docker-dev-1` | Compose · `homelab-zensical-l9cgdm` | built from repo | `docs.home.capilabs.dev` | — | — | This site. Local only |

## tenant-os

| Service | Node | Deploy · stack | Version | Domains | Host ports | Data |
|---|---|---|---|---|---|---|
| Registrar DB | `docker-dev-1` | Compose · `tenantos-tenantos-registrar-db-server-22ikq3` | Postgres 17.11 | — | 54321 | `tenant-os-db-server` + custom `postgresql.conf`, Databasus backup user |
| Tenants DB | `docker-dev-1` | Compose · `tenantos-tenantos-tenants-serverdb-yhuk6y` | Postgres 17.11 | — | 54322 | `tenant-os-tenants-db-server` + custom `postgresql.conf`, Databasus backup user |
| Redis | `docker-worker-1` | Swarm · `tenantos-tenants-redis-db-d82cuj` | Redis 7 | — | — | `redis-data` |
| Mailpit | `docker-worker-1` | Swarm · `tenantos-mailpit-z13wcp` | `latest` | `mailpit.homelab…`, `mailpit.home…` | `*:1025` (SMTP), `*:9005` (UI) — ingress | `mailpit-data` |

`…homelab…` = `.homelab.capilabs.dev` (public), `…home…` = `.home.capilabs.dev` (local). Volume names are prefixed with the stack name on disk under `/var/lib/docker/volumes/`.

## Outside Docker

| Service | Where | Address | Notes |
|---|---|---|---|
| Technitium DNS | LXC 108 on `pvemaster1` | `192.168.10.2` | Native install — [how to build one](technitium-dns-lxc.md) |
| Headlamp | Kubernetes | MetalLB IP in `192.168.30.210–250` | Remote access via Tailscale (VLAN 30 route) |

## Planned

| Service | Where | Notes |
|---|---|---|
| Pterodactyl Panel | `docker-worker-1`, Dokploy | MariaDB + Redis, `pterodactyl.homelab.capilabs.dev` |
| Pterodactyl Wings | VM 110 `wings-gameserver-01` on `pvenode1` (created, stopped), plain Compose | Needs host net, privileged, docker.sock |
| PostgreSQL HA (Patroni + etcd) | 3 VMs on VLAN 40 | Learning lab; VMs not created yet |
| MariaDB Galera + MaxScale | 3 VMs | Learning lab, latest stable MariaDB |

## Retired

| Service | Replaced by / reason |
|---|---|
| GitLab CE + registry | Forgejo |
| `prod-postgres`, `prod-postgres-lite` | Removed from `docker-dev-1` |
