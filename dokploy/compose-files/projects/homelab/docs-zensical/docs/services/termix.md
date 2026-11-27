# Termix (web SSH)

Browser-based SSH client and server manager.

| | |
|---|---|
| Compose | `dokploy/compose-files/projects/homelab/termix/compose.yml` |
| Dokploy app | Swarm · TODO: stack name |
| Node | `docker-worker-1` |
| Image | `ghcr.io/termix-ssh/termix:latest` |
| URL | `https://ssh.home.capilabs.dev` (local only) |
| Data | bind `/mnt/docker-storage/termix` → `/app/data` |

TODO: confirm Termix is deployed (it's not in the 2026-10-06 service catalog snapshot).

The public router (`ssh.homelab.capilabs.dev`) is commented out in `compose.yml`. Turn it on only
after TOTP/OIDC (authentik) or Cloudflare Access protects the login: it gives shell access to the
servers.

Note: the sample env file here is `env.sample`, not `.env.sample` like the other services.
