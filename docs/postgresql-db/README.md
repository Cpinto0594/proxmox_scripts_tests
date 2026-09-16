# Prod PostgreSQL — setup

## 1. Prep the host (docker-dev-1)
```bash
sudo mkdir -p /mnt/fast-storage/postgres-data
```

## 2. Add postgresql.conf as a File Mount
This is a Compose app, so Dokploy's Advanced → Mounts only exposes **File
Mount** (Volume Mount is an Application-type-only option — for Compose,
the `postgres_data` named volume is just declared straight in the YAML, no
separate UI step needed). Static config text, on the other hand, has to go
through File Mount or it won't survive AutoDeploy:

Go to Advanced → Mounts → Add → File Mount, then:
- **File Path:** `postgresql.conf`
- **Content:** paste the contents of `postgresql.conf` from this bundle
- **Mount Path:** doesn't matter for Compose apps — the compose file's own
  volume line (`../files/postgresql.conf:/etc/postgresql/postgresql.conf:ro`)
  controls where it actually lands in the container

Dokploy stores this under `/files/postgresql.conf` and keeps it across
redeploys — unlike a bind mount pointed at the repo checkout, which gets
wiped on every AutoDeploy git clone.

**If you already created this File Mount before `listen_addresses = '*'`
was added to `postgresql.conf`:** editing the local file in this bundle
does nothing on its own — Dokploy's File Mount content only changes when
you go back into Advanced → Mounts and re-paste the updated file content
there, then redeploy. This exact line is why Postgres was refusing every
external connection despite the health check passing: this custom config
replaces the file the entrypoint normally patches to `'*'`, so without it
Postgres silently falls back to `listen_addresses = 'localhost'`.

## 3. Set the credentials in Dokploy
Generate a password, then add it under the Compose service's **Environment**
tab in Dokploy — not as a plaintext value committed anywhere:
```bash
openssl rand -base64 24
```
Add these as environment variables in Dokploy (service-level, not shared,
so other projects on the same instance can't read them):
```
POSTGRES_DB=appdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD=<paste the generated value>
```
Dokploy writes these into a `.env` file next to the compose file at deploy
time and the compose file above picks them up via `${POSTGRES_PASSWORD}`
interpolation — no secret ever needs to live in your git repo or the raw
compose text.

**Tighter alternative:** if you'd rather not have the password readable via
`docker exec ... printenv` inside the container, use the same File Mount
mechanism for the password too: paste it as file content, then swap the
compose file back to the `POSTGRES_PASSWORD_FILE:
/run/secrets/postgres_password` + top-level `secrets: { postgres_password:
{ file: ../files/postgres_password.txt } }` pattern. More steps, real Docker
secret semantics.

**If you already run a vault** (HashiCorp Vault/OpenBao, Infisical, Doppler,
AWS Secrets Manager, Azure Key Vault, or Scaleway Secret Manager), Dokploy
can pull the value at deploy time and never store it at all:
`POSTGRES_PASSWORD=${{vault.my-vault.myapp/prod:POSTGRES_PASSWORD}}`. Worth
it if you're already running one of those; not worth standing one up just
for this.

## 4. Bring it up
Deploy from the Dokploy UI, or:
```bash
docker compose up -d
docker compose logs -f prod-postgres
```

## Don't repeat the Dokploy Postgres password gotcha
`POSTGRES_PASSWORD` (file-based or plain env var) is only read by the
official image during `initdb` — the very first time the data volume is
empty. If you ever change the `POSTGRES_PASSWORD` variable in Dokploy and
redeploy against an **existing** `postgres_data` volume, Postgres won't pick
up the new password and auth will fail. To rotate the password later, do it
from inside Postgres first, then update the Dokploy variable to match:
```bash
docker compose exec prod-postgres psql -U appuser -d appdb \
  -c "ALTER USER appuser WITH PASSWORD 'new-password-here';"
```

## Accessing the DB from outside the container
The compose file binds `5432` to two specific host IPs — `docker-dev-1`'s
Tailscale IP and its LAN IP (`192.168.10.10` on `ens18`, confirmed via
`ip -4 addr show`) — nothing listens on `0.0.0.0` or any other interface.
Tailscale's own WireGuard auth gates the first; the second is reachable
from anywhere on `192.168.10.0/24` by virtue of which interface it's bound
to, no firewall rule required for either.

**One-time setup, if `docker-dev-1` doesn't have Tailscale yet:**
```bash
# [docker-dev-1]
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up                        # follow the login URL, same tailnet as your other devices
sudo systemctl enable --now tailscaled   # confirm it survives reboots
tailscale ip -4                          # note this — e.g. 100.100.50.12
ip -4 addr show                          # note the LAN IP too — docker-dev-1's is 192.168.10.10 on ens18
```
Then in **Dokploy → Environment tab** for this app, add both:
```
TAILSCALE_IP=100.100.50.12
LAN_IP=192.168.10.10
```
and redeploy with an explicit `docker compose down && docker compose up -d`
rather than just Deploy — you've hit before that Dokploy's Deploy button
doesn't always force a full recreate after env changes, and a port-binding
change needs one.

**Make sure `docker-dev-1`'s LAN IP is actually static** — a DHCP
reservation on the MikroTik, the same way your Proxmox nodes already have
fixed addresses on their own subnet (`192.168.1.90`/`.91` — a different
range than `docker-dev-1`'s `192.168.10.0/24`). If `docker-dev-1` is on
plain DHCP with no reservation, a lease renewal can hand it a different
address and silently break this binding until you notice and update
`LAN_IP` — which is exactly what happened here: `192.168.1.41` was never
a real address on this host at all.

**Validate it worked:**
```bash
# [docker-dev-1] — confirm both binds, not 0.0.0.0
docker port <prod-postgres container>
sudo ss -tlnp | grep 5432

# [any other device on your tailnet] — confirm Tailscale path works
tailscale ping docker-dev-1
psql -h 100.100.50.12 -p 5432 -U appuser -d appdb -c "select 1;"

# [any other device on 192.168.10.0/24] — confirm LAN path works
psql -h 192.168.10.10 -p 5432 -U appuser -d appdb -c "select 1;"

# [a device on neither — e.g. phone on cellular, Tailscale off] — confirm it's closed off
nmap -p 5432 100.100.50.12    # and the public IP, if you have one — both should time out / refuse
```

**Confirmed: this runs under Dokploy in Swarm/Stack mode, not plain
Compose.** The short `"IP:port:port"` syntax doesn't reliably bind to a
specific host IP under Swarm's ingress routing mesh — with the short
syntax, it can throw the same
`failed to bind host port <ip>:<port>/tcp: cannot assign requested address`
error even when the IP is correct, because Swarm tries to program it
through the ingress mesh (`docker_gwbridge`) rather than a direct host
bind. The compose file uses the long syntax with `mode: host` instead,
which Swarm does honor as a direct per-node bind:
```yaml
ports:
  - target: 5432
    published: 5432
    protocol: tcp
    mode: host
    host_ip: "${TAILSCALE_IP}"
  - target: 5432
    published: 5432
    protocol: tcp
    mode: host
    host_ip: "${LAN_IP}"
```
The placement constraint (`node.hostname == docker-dev-1`) is set for the
same reason — with `mode: host`, a task rescheduled onto a different node
wouldn't have either IP and would hit the exact same error.

**Same error message, second possible cause — the one we actually hit:**
after switching to `mode: host`, this exact "cannot assign requested
address" error came back for `LAN_IP`, and that time it wasn't a Swarm
quirk at all — `192.168.1.41` simply wasn't a real address on
`docker-dev-1`. `ip -4 addr show` showed its actual LAN IP as
`192.168.10.10`. Check that directly whenever this error shows up:
```bash
# [docker-dev-1]
ip -4 addr show   # confirm TAILSCALE_IP and LAN_IP both appear here, exactly
```
A mismatch here is almost always a stale `LAN_IP` value from before a DHCP
lease renewal (see the static-IP note above), or `tailscaled` not actually
up yet when Dokploy redeployed.

**If you want to narrow the LAN binding further** (say, only your desk and
not the whole `/24`), layer a `DOCKER-USER` rule on top — Docker inserts its
own rules ahead of `ufw`'s, so `ufw` alone won't do anything:
```bash
sudo iptables -A DOCKER-USER -p tcp --dport 5432 -j DROP
sudo iptables -I DOCKER-USER -p tcp --dport 5432 -s 203.0.113.10/32 -j RETURN
sudo apt install iptables-persistent && sudo netfilter-persistent save
```

**If you do ever expose this to real internet traffic** (not just Tailscale
or LAN), turn on TLS in `postgresql.conf` (`ssl = on` + a cert) — by default
Postgres sends credentials and query data in the clear.

## Exposing this via Cloudflare Tunnel (no Traefik)
`prod-postgres` is joined to `dokploy-network` specifically so your existing
`cloudflared` Compose service can reach it directly by name — no Traefik TCP
entrypoint, no swarm service port-publish, none of that. Just add a Public
Hostname to the tunnel:
- Zero Trust dashboard → Networks → Tunnels → your tunnel → Public Hostname → Add
- Service Type: **TCP**, URL: **`prod-postgres:5432`**

Or, if `cloudflared` is locally-managed via a mounted `config.yml`:
```yaml
ingress:
  - hostname: db.capilabs.dev
    service: tcp://prod-postgres:5432
  - service: http_status:404   # required catch-all, must be last
```
Confirm `cloudflared` itself is attached to `dokploy-network` — otherwise it
can't resolve `prod-postgres` at all.

To connect: install `cloudflared` on the client machine, then
`cloudflared access tcp --hostname db.capilabs.dev --url 127.0.0.1:5432`,
and point psql/pgAdmin/DBeaver at `localhost:5432`. Consider adding a
Cloudflare Access policy on that hostname (Zero Trust → Access →
Applications) restricted to your email or a service token — that gates the
connection behind authentication before Cloudflare even proxies it.

Since you already run Tailscale, this Cloudflare path is really only worth
it for devices that aren't on your tailnet. If everything that'll ever touch
this DB already is, Tailscale alone is simpler — skip this section.

## Scaling resources
Bumping `deploy.resources.limits` in `docker-compose.yml`? Recalculate
`shared_buffers` (~25%) and `effective_cache_size` (~75%) in `postgresql.conf`
to match the new memory limit.
