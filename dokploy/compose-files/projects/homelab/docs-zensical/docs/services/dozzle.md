# Dozzle (container log viewer)

Real-time log viewer for every container in the Swarm.

| | |
|---|---|
| Compose | `dokploy/compose-files/projects/homelab/dozzle/compose.yml` |
| Dokploy app | Swarm · `homelab-dozzle-8apzz5` |
| Mode | `global`: one replica per Swarm node (`docker-dev-1`, `docker-worker-1`), peering over the `dozzle` overlay |
| URLs | `https://dozzle.homelab.capilabs.dev` (public, tunnel), `https://dozzle.home.capilabs.dev` (local) |
| Data | bind `/mnt/docker-storage/dozzle` → `/data`, **on each node separately** |
| Auth | authentik SSO: [forward auth](authentik-forward-auth.md) + `DOZZLE_AUTH_PROVIDER=forward-proxy` |

## Authentication (authentik SSO)

Traefik sends every request through authentik's embedded outpost (`authentik@file`). Dozzle takes
the user from the headers authentik adds. The full pattern, the shared Traefik file and the checks
are on [authentik forward auth](authentik-forward-auth.md).

Dozzle environment:

```yaml
      DOZZLE_AUTH_PROVIDER: forward-proxy
      DOZZLE_AUTH_HEADER_USER: X-Authentik-Username
      DOZZLE_AUTH_HEADER_EMAIL: X-Authentik-Email
      DOZZLE_AUTH_HEADER_NAME: X-Authentik-Name
      DOZZLE_AUTH_LOGOUT_URL: https://dozzle.home.capilabs.dev/outpost.goauthentik.io/sign_out
```

Traefik routers (labels in `compose.yml`):

| Router | Rule | Entrypoint | Middlewares | Service |
|---|---|---|---|---|
| `dozzle-public` | `Host(dozzle.homelab.capilabs.dev)` | `web` | `forwarded-https@file`, `authentik@file` | `dozzle` |
| `dozzle-local` | `Host(dozzle.home.capilabs.dev)` | `websecure` | `authentik@file` | `dozzle` |
| `dozzle-outpost-public` | same host + `PathPrefix(/outpost.goauthentik.io/)` | `web` | `forwarded-https@file` | `authentik-outpost@file` |
| `dozzle-outpost-local` | same host + `PathPrefix(/outpost.goauthentik.io/)` | `websecure` | — | `authentik-outpost@file` |

authentik objects: proxy provider + application `dozzle-local` (External host
`https://dozzle.home.capilabs.dev`), added to the **authentik Embedded Outpost**. Login on the
local URL checked 2026-11-21.

TODO: confirm the `dozzle-public` provider/application (`https://dozzle.homelab.capilabs.dev`)
exists, is in the Embedded Outpost, and that a public login works end to end.

TODO: bind an admin group to the Dozzle applications. Until then, any authentik user can read
every container's logs.

Both routers must keep `authentik@file`. With `forward-proxy`, Dozzle trusts the
`X-Authentik-*` headers, so an unprotected router would let anyone pick their user name.

`DOZZLE_AUTH_LOGOUT_URL` takes one URL and points at the local host, so signing out from the
public URL while off the LAN fails. Switch it to the public host if that's the usual way in.

### Old `simple` auth (removed)

Before SSO, Dozzle used `DOZZLE_AUTH_PROVIDER=simple` with `/data/users.yml`. `/data` is a local
bind mount on a global service, so every node needed its own copy of the file, and a node without
it crash-looped with `fatal No users.yaml or users.yml file found`. If you ever go back to it,
generate the file with `docker run --rm amir20/dozzle:latest generate admin --password ...` and
install it on both nodes under `/mnt/docker-storage/dozzle/`.

TODO: delete the leftover `users.yml` from `/mnt/docker-storage/dozzle/` on `docker-dev-1` and
`docker-worker-1` (the password was at `infisical:/homelab/dozzle/admin-password`).
