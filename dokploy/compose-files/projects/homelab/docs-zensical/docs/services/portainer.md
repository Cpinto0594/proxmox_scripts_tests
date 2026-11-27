# Portainer (Docker UI)

Web UI for the Docker hosts.

| | |
|---|---|
| Compose | `dokploy/compose-files/projects/homelab/portainer/compose.yml` |
| Dokploy app | Compose · `homelab-portainer-ydf7mb` |
| Node | `docker-dev-1` |
| Image | `portainer/portainer-ce:latest` |
| URLs | `https://portainer.homelab.capilabs.dev` (public, tunnel), `https://portainer.home.capilabs.dev` (local) |
| Host ports | `9001` → `9443` (HTTPS UI), `8000` (Edge agent tunnel), bound to `${TAILSCALE_IP}` and `${DOCKER_NODE_IP}` (`192.168.40.10`) only |
| Data | bind `/mnt/docker-storage/portainer` → `/data` |

Mounts `/var/run/docker.sock`, so access to Portainer is root on `docker-dev-1`.

TODO: move the login to [authentik](authentik.md) (see [open items](../open-items.md)).
