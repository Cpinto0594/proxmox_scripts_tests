# Forgejo (Git + CI)

Self-hosted Git forge: repos, package registry and Forgejo Actions CI. Replaced GitLab CE.

| | |
|---|---|
| Compose | `dokploy/compose-files/projects/homelab/forgejo/compose.yml` (forge), `forgejo/runner-compose.yml` (runners) |
| Dokploy app | Swarm · `homelab-forgejo-rgu8rl` (forge), Swarm · `homelab-forgejo-runner1-a28nkd` (runners) |
| Node | `docker-worker-1` (forge, DB, Redis and `forgejo-runner1`), `docker-dev-1` (`forgejo-runner2`) |
| Images | `codeberg.org/forgejo/forgejo:10`, `postgres:16-alpine`, `redis:7-alpine`, `code.forgejo.org/forgejo/runner:12.9.0` |
| URLs | `https://forgejo.homelab.capilabs.dev` (public, tunnel), `https://forgejo.home.capilabs.dev` (local) |
| Git over SSH | port `2222`, published in host mode on `docker-worker-1` (doesn't go through the tunnel) |
| Data | binds under `/mnt/docker-storage/forgejo/` (`data`, `db`, `redis`), runners under `/mnt/docker-storage/forgejo-runner{1,2}/data` |
| Secrets | `.env.sample` in the compose dir. TODO: confirm Infisical paths (e.g. `infisical:/homelab/forgejo/db-password`) |

## Stack

- `forgejo-db` and `forgejo-redis` sit only on the `forgejo-internal` overlay (`internal: true`).
- Forgejo uses Redis for cache (db 0), sessions (db 1) and queues (db 2).
- The entrypoint waits 20 s before starting, and the restart policy has no `max_attempts`, because
  Swarm ignores `depends_on` and the first tries after a cold start can fail.
- Registration is disabled (`DISABLE_REGISTRATION=true`). OAuth2 client login is on with
  auto-registration (for authentik). TODO: document the authentik OIDC setup.

## Runners

Two runners, one per node, both mount `/var/run/docker.sock` so job containers run next to them
on the host's Docker.

TODO: the service catalog (2026-10-06) only lists `forgejo-runner1`. Confirm `forgejo-runner2`
on `docker-dev-1` is deployed.

Register a runner (token from Forgejo → Site administration → Actions → Runners):

```bash
docker run --rm -it --user 0:0 -v /mnt/docker-storage/forgejo-runner2/data:/data \
  code.forgejo.org/forgejo/runner:12.9.0 \
  forgejo-runner register --no-interactive \
    --token <token> \
    --name docker-runner2 \
    --instance https://forgejo.home.capilabs.dev \
    --labels docker:docker://node:20-bookworm,ubuntu-latest:docker://catthehacker/ubuntu:act-latest,self-hosted

docker run --rm code.forgejo.org/forgejo/runner:12.9.0 \
  forgejo-runner generate-config > /mnt/docker-storage/forgejo-runner2/data/config.yaml
```

## Create an admin user

```bash
docker exec -u git -it $(docker ps -qf name=homelab-forgejo-rgu8rl_forgejo) \
  forgejo admin user create --username <user> --password '<password>' --email <email> --admin
```
