# Cloudflare Tunnel (cloudflared)

Brings public traffic for `*.homelab.capilabs.dev` into the homelab without opening router ports.
cloudflared sends it to Traefik's `web` entrypoint (plain HTTP, Cloudflare terminates TLS).

| | |
|---|---|
| Compose | `dokploy/compose-files/projects/homelab/cloudflare-tunnel/docker-compose.yml` |
| Dokploy app | Compose · `local-infra-cloudflare-tunnel-e0cbqi` |
| Node | `docker-dev-1` |
| Container | `cloudflare_tunnel` |
| Image | `cloudflare/cloudflared:latest` |
| Config | `TUNNEL_TOKEN` from `CLOUDFLARE_TUNNEL_TOKEN`. TODO: confirm the Infisical path |

Public hostnames are set in the Cloudflare Zero Trust dashboard, not in this repo. See
[Network](../network/README.md) and [Dokploy / Swarm](../platforms/dokploy-swarm.md) for the flow.

TODO: the compose file attaches the service to `infra-network` but only declares
`dokploy-network`. Check which network the running container is on and fix the file.
