# Dozzle (container log viewer)

Real-time log viewer for every container in the Swarm.

| | |
|---|---|
| Compose | `dokploy/compose-files/projects/homelab/dozzle/compose.yml` |
| Dokploy app | Swarm · `homelab-dozzle-8apzz5` |
| Mode | `global`: one replica per Swarm node (`docker-dev-1`, `docker-worker-1`), peering over the `dozzle` overlay |
| URLs | `https://dozzle.homelab.capilabs.dev` (public, tunnel), `https://dozzle.home.capilabs.dev` (local) |
| Data | bind `/mnt/docker-storage/dozzle` → `/data`, **on each node separately** |
| Auth | `DOZZLE_AUTH_PROVIDER=simple`: users in `/data/users.yml` |

## Users file (`users.yml`)

The `simple` auth provider reads `/data/users.yml` and the container exits at startup without it:

```text
fatal No users.yaml or users.yml file found. | version=v11.4.3
```

`/data` is a **local bind mount** and the service is **global**, so every node needs its own copy
of the file. If it exists on only one node, the replica on the other node crash-loops with the
error above.

Generate the file once. It holds a bcrypt hash, not the password, but keep it out of the repo
anyway. Store the password at `infisical:/homelab/dozzle/admin-password`.

```bash
read -rsp 'Dozzle admin password: ' DOZZLE_PW; echo
docker run --rm amir20/dozzle:latest generate admin \
  --password "$DOZZLE_PW" --email you@example.com --name "Admin" > users.yml
unset DOZZLE_PW
cat users.yml   # expect: users: / admin: / name, email, password: $2a$...
```

Install it on **every** node (`docker-dev-1` = `192.168.40.10`, `docker-worker-1` = `192.168.40.11`):

```bash
for h in 192.168.40.10 192.168.40.11; do
  scp users.yml "$h":/tmp/users.yml
  ssh -t "$h" 'sudo mkdir -p /mnt/docker-storage/dozzle &&
               sudo install -m 0644 /tmp/users.yml /mnt/docker-storage/dozzle/users.yml &&
               rm /tmp/users.yml && ls -l /mnt/docker-storage/dozzle/'
done
rm users.yml
```

Then restart the service and check that both replicas stay up:

```bash
# on docker-dev-1 (manager)
svc=$(docker service ls --format '{{.Name}}' | grep dozzle)
docker service update --force "$svc"
docker service ps "$svc" --no-trunc    # both nodes Running, no repeated Failed rows
```

Adding or changing a user means editing `users.yml` on **both** nodes.

TODO: replace with authentik SSO (Traefik forward-auth + `DOZZLE_AUTH_PROVIDER=forward-proxy`).
Then there's no per-node file to keep in sync. Tracked in [open-items](../open-items.md).
