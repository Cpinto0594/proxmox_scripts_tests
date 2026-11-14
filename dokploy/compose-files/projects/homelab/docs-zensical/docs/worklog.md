# Work log

Chronological record of work done on the homelab and this repo, newest first.
Each entry: what changed, why, files touched, and follow-ups. Keep the detailed
"how" on the relevant topic page and link to it from here.

---

## 2026-11-14 — Dozzle: `No users.yaml or users.yml file found`

**What:** Dozzle (v11.4.3) exited at startup with `fatal No users.yaml or users.yml file found`.
The stack uses `DOZZLE_AUTH_PROVIDER=simple`, which needs `/data/users.yml`. `/data` is a local bind
mount (`/mnt/docker-storage/dozzle`) and the service is `global`, so each node needs its own copy.
Added a Dozzle page with the generate and install-on-every-node steps, a gotcha about global
services with bind mounts, a nav entry, and a comment in the compose file.

**Why:** Dozzle replica crash-looping.

**Files:** `dozzle/compose.yml`, `docs-zensical/zensical.toml`, `docs-zensical/docs/services/dozzle.md` (new),
`docs-zensical/docs/services/README.md`, `docs-zensical/docs/gotchas.md`, `docs-zensical/docs/worklog.md`

**Follow-ups:**

- [ ] Generate `users.yml`, install it on `docker-dev-1` and `docker-worker-1`, force-update the service.
- [ ] Later: move Dozzle to authentik forward-auth (already in open-items) and drop `users.yml`.

---

## 2026-11-13 — Proxmox OpenID login to authentik fails with TLS alert 40

**What:** Logging in to Proxmox through the new authentik OpenID realm failed with `ureq request
failed - native-tls: ... ssl/tls alert handshake failure ... SSL alert number 40`. Reproduced: via
`1.1.1.1`, `authentik.home.capilabs.dev` resolves to Cloudflare (`104.21.11.163`, `172.67.166.108`,
wildcard under `capilabs.dev`), and a TLS handshake there with that SNI gets alert 40. Cloudflare
has no certificate for `*.home.capilabs.dev`. Through Technitium the name resolves to Traefik
(`192.168.40.10`) with a valid Let's Encrypt certificate. So `pveproxy` on the node is resolving
through a public DNS server, not Technitium. Documented the Proxmox realm setup, the check and the fix.

**Why:** Proxmox SSO via authentik.

**Files:** `docs-zensical/docs/services/authentik.md`, `docs-zensical/docs/gotchas.md`,
`docs-zensical/docs/worklog.md`

**Follow-ups:**

- [ ] Add `192.168.40.10 authentik.home.capilabs.dev` to `/etc/hosts` on `pvemaster1`, `pvenode1`, `pvenode2`, then retry the login. Chosen over pointing node DNS at Technitium because Technitium (LXC 108) runs on `pvemaster1`, which would be a circular dependency.
- [ ] TODO: record each node's current `/etc/resolv.conf` in [Proxmox](platforms/proxmox.md).

---

## 2026-11-13 — authentik DB role limited to its own database

**What:** The authentik DB setup only ran `REVOKE ALL ON DATABASE authentik FROM PUBLIC`, which
keeps other roles out of `authentik` but leaves `authentik` able to connect to every other database
through the default `PUBLIC` `CONNECT` grant. Added a cluster-wide, re-runnable loop that revokes
`CONNECT` from `PUBLIC` on all databases, a pre-check query (owners, ACLs, who is connected), and
verification commands. The role is now created with explicit `NOSUPERUSER NOCREATEDB NOCREATEROLE
NOREPLICATION NOBYPASSRLS`.

**Why:** Owner wants the `authentik` role to see only the authentik database.

**Files:** `docs-zensical/docs/services/authentik.md`, `docs-zensical/docs/gotchas.md`,
`docs-zensical/docs/worklog.md`

**Follow-ups:**

- [ ] Run the pre-check, then the revoke loop on the cluster. Re-run the loop whenever a new app DB is added.
- [ ] Optional: per-role `pg_hba` lines (TODO in the authentik page), after checking where Patroni keeps `pg_hba`.

---

## 2026-11-13 — Patroni client port is 54321, not 5000

**What:** Connecting to the Patroni VIP on `:5000` failed with `Connection refused`. A probe of
VLAN 40 showed `:5000` refused on the VIP and all three nodes, while `:5432` was open and Patroni's
`/primary` returned 200 on `pg1` only (cluster healthy, `pg1` leader). The owner's
`/etc/haproxy/haproxy.cfg` has `bind *:54321`, and `:54321` is open on the VIP and every node. The
docs had said 5000 everywhere. Corrected the port across the docs and the authentik stack.

Also found in the same config: Ubuntu's stock `defaults` set `timeout client/server 50000` (50 s),
which drops idle pooled Postgres connections. The guide now sets 30 min in the `listen` block. All
three `pg` VMs present the same SSH host key (cloned without regenerating).

**Why:** authentik's DB setup (and every future app) has to use the right port. VIP `:5432` isn't a
safe fallback because it goes to whichever node holds the VIP, not the Patroni leader.

**Files:** `docs-zensical/docs/services/patroni-cluster-guide.md` (port, HAProxy block with
timeouts + `tcplog`, config check, two troubleshooting rows), `docs-zensical/docs/services/authentik.md`,
`docs-zensical/docs/services/README.md`, `docs-zensical/docs/inventory/ip-plan.md`,
`docs-zensical/docs/gotchas.md`, `docs-zensical/docs/open-items.md`, `docs-zensical/docs/worklog.md`
(port in the entry below), `authentik/compose.yml` (header comment), `authentik/.env.sample`
(`PG_PORT=54321`)

**Follow-ups:**

- [ ] Apply the HAProxy timeout/`tcplog` change on `pg1`–`pg3` and reload.
- [ ] Regenerate SSH host keys on `pg1`–`pg3`.
- [ ] Set `PG_PORT=54321` in the authentik Dokploy environment.
- [ ] If anything outside VLAN 40 needs the DB, the MikroTik rule must allow `54321`, not 5000.

---

## 2026-11-13 — authentik compose stack (SSO)

**What:** Added a Swarm-type compose stack for authentik 2026.8.5 at
`dokploy/compose-files/projects/homelab/authentik/` (`compose.yml` + `.env.sample`):
`authentik-server` (Traefik public + local routers on `:9000`) and `authentik-worker`, pinned to
`docker-worker-1` with bind volumes under `/mnt/docker-storage/authentik/`. **External database**:
no bundled Postgres. `PG_HOST`/`PG_PORT` default to the Patroni VIP `192.168.40.120:54321`, and the
role/DB are created by hand. New page [authentik](services/authentik.md) with deploy steps.

**Why:** One login for the homelab apps instead of a separate account in each.

**Choices:** External DB because authentik recommends running Postgres separately from its example stack, and the cluster gives HA and shared backups. No Redis (removed upstream in 2025.10). `shm_size` replaced by a tmpfs on `/dev/shm`
(Swarm ignores `shm_size`). Worker has no `docker.sock` and doesn't run as root. Public router
forces `X-Forwarded-Proto=https`, since Traefik sees cloudflared's traffic as plain HTTP.

**Also:** The Patroni cluster (`pg1`–`pg3`, VIP `192.168.40.120:54321`) is up and is now the main Postgres cluster (owner confirmed). Moved it from *Planned* to *Outside Docker* in the catalog, added its IPs to the IP plan, and put a status line on the guide.

**Tested:** `docker compose config` passes. Not deployed.

**Files:** `dokploy/compose-files/projects/homelab/authentik/compose.yml`,
`dokploy/compose-files/projects/homelab/authentik/.env.sample`,
`docs-zensical/docs/services/authentik.md`, `docs-zensical/docs/services/README.md`,
`docs-zensical/docs/open-items.md`, `docs-zensical/docs/inventory/ip-plan.md`,
`docs-zensical/docs/services/patroni-cluster-guide.md`, `docs-zensical/zensical.toml`

**Follow-ups:**

- [ ] Create the `authentik` role + DB on the cluster, check `max_connections`.
- [ ] Create the dirs on `docker-worker-1`, put the secrets in Infisical, deploy from Dokploy (Swarm type).
- [ ] Cloudflare tunnel route + Technitium record for the two names.
- [ ] Confirm the public name gives `https://` issuer/redirect URLs.
- [ ] Check `docker-worker-1` RAM (6 GB, already runs Forgejo) once it's running.
- [ ] Add the authentik DB to Databasus.

---

## 2026-11-09 — Shared console name: failover instead of load balancing

**What:** `dns.home.capilabs.dev` in `dokploy/traefik/dynamic/technitium-lxc.yml` is now a
Traefik **failover** service: always the Primary (`192.168.10.2`, health check on `/`
every 10 s), and the Secondary only while the Primary is down. Removed the round-robin
load balancer and sticky cookie from the entry below. `dns1`/`dns2` direct names kept.
Recorded the current cluster on the docs page: LXC 108 is **Primary**, `dns2` is a
**Secondary** (read-only replica).

**Why:** The two servers are clustered and `dns2` is a Secondary, so it can't edit zones.
Load-balancing would send some sessions there.

**Tested:** YAML parses. Not loaded into a real Traefik (couldn't run Traefik here).

**Files:** `dokploy/traefik/dynamic/technitium-lxc.yml`,
`docs-zensical/docs/services/technitium-dns-lxc.md`

**Follow-ups:**

- [ ] Apply on `docker-dev-1`, check the Traefik dashboard shows `technitium-lxc` as a failover service without errors.
- [ ] Fill in the Secondary's CTID / node / IP (placeholder `192.168.10.3`) and the cluster domain.
- [ ] Test failover in a maintenance window (`pct stop 108`).

---

## 2026-11-09 — One name for both Technitium consoles (Traefik load balancer)

**What:** `dns.home.capilabs.dev` now load-balances both Technitium consoles in
`dokploy/traefik/dynamic/technitium-lxc.yml`, with a sticky cookie (`technitium_node`,
because login sessions are per server) and a health check on `/` (failover; you log in
again on the other server). Direct names `dns1` (→ `192.168.10.2`) and `dns2` (→ second
server) kept for reaching one server. Replaces the earlier "separate route only" entry
below. Documented in
[Web console through Traefik](services/technitium-dns-lxc.md#web-console-through-traefik).

**Note:** only the console is load-balanced; DNS on port 53 isn't behind Traefik.
Unclustered servers have separate configs, so changes via the shared name hit only one.

**Files:** `dokploy/traefik/dynamic/technitium-lxc.yml`,
`docs-zensical/docs/services/technitium-dns-lxc.md`

**Follow-ups:**

- [ ] Apply the file on `docker-dev-1` (replaces the current single-server `technitium-lxc` service).
- [ ] Add A records for `dns1`/`dns2` unless `home.capilabs.dev` has a wildcard.
- [ ] Decide on clustering so both consoles show the same config.

---

## 2026-11-09 — Traefik route for the second Technitium console

**What:** Added `dns2.home.capilabs.dev` → `http://192.168.10.3:5380` as its own
router + service next to the existing `dns.home.capilabs.dev` one, and put the
Traefik dynamic config in the repo for the first time
(`dokploy/traefik/dynamic/technitium-lxc.yml`). Documented in
[Technitium DNS in an LXC → Web console through Traefik](services/technitium-dns-lxc.md#web-console-through-traefik).

**Why separate, not a second URL in the same load balancer:** Technitium sessions are
per server; round-robin would keep logging you out and hide which server you edit.

**Files:** `dokploy/traefik/dynamic/technitium-lxc.yml`,
`docs-zensical/docs/services/technitium-dns-lxc.md`

**Follow-ups:**

- [ ] Copy the new router/service into Traefik's dynamic config on `docker-dev-1`.
- [ ] Set the real IP of the second server (placeholder `192.168.10.3`).
- [ ] Confirm the dynamic config path on `docker-dev-1` and whether `home.capilabs.dev`
  has a wildcard record (else add an A record for `dns2`).

---

## 2026-11-08 — Technitium clustering ports (documented)

**What:** Checked whether a server built by `create-technitium-lxc.sh` is ready for
Technitium clustering. Nothing filters the ports (`firewall=0` on the NIC, no firewall
in the image, same VLAN). The cluster port 53443/tcp (HTTPS API) isn't listening until
HTTPS is turned on, which cluster init/join does automatically with a self-signed
certificate. No script change. Added a *Clustering* section (ports, steps, warning that
joining overwrites the Secondary's config) to
[Technitium DNS in an LXC](services/technitium-dns-lxc.md#clustering).

**Source:** Technitium `APIDOCS.md` (cluster init / initJoin calls).

**Files:** `docs-zensical/docs/services/technitium-dns-lxc.md`

**Follow-ups:**

- [ ] Decide whether to cluster the production server with a second one, and whether
  to use a real certificate for the web service first.

---

## 2026-11-08 — Technitium LXC script: install jq on the node if missing

**What:** `scripts/proxmox/create-technitium-lxc.sh` checks for `jq` on the Proxmox
node during pre-flight and installs it with `apt-get` if it isn't there (retrying
after `apt-get update`). It stops with a clear message if the install fails.

**Why:** The script parses the Technitium API responses with `jq` on the node, and
Proxmox VE doesn't include `jq` by default — the first real run would have failed
at the login step.

**Tested:** `shellcheck` and the stand-in test run: jq missing (installed once),
jq present (no install), install failing (clear error).

**Files:** `scripts/proxmox/create-technitium-lxc.sh`,
`docs-zensical/docs/services/technitium-dns-lxc.md`

**Follow-ups:** none new.

---

## 2026-11-08 — Technitium LXC script: prompt defaults and image picker

**What:** In `scripts/proxmox/create-technitium-lxc.sh`:

- Pressing Enter at a prompt takes the default: `technitium-dns-2` for the
  hostname, `dns2.home.capilabs.dev` for the Technitium domain. The password still
  has no default.
- New prompt for the **container image** (`TEMPLATE`): a numbered list of the
  Debian/Ubuntu templates from `pveam available`; enter a number, a name, or Enter
  for the newest `TEMPLATE_PATTERN` match. Invalid answers ask again. `--ostype`
  follows the chosen image (debian/ubuntu).
- Without a terminal, hostname/domain/image use their defaults; only
  `ADMIN_PASSWORD` must be set.

**Why:** Faster runs (Enter through the prompts), and a way to pick e.g. Debian 13
or Ubuntu without editing the script.

**Tested:** `shellcheck` and the stand-in Proxmox test run (Enter for everything,
pick by number, by name, invalid input, no terminal).

**Files:** `scripts/proxmox/create-technitium-lxc.sh`,
`docs-zensical/docs/services/technitium-dns-lxc.md`

**Follow-ups:** none new.

---

## 2026-11-08 — Technitium LXC script: prompt for hostname and domain

**What:** `scripts/proxmox/create-technitium-lxc.sh` now asks for `CT_HOSTNAME` and
`DNS_SERVER_DOMAIN` (as well as the admin password) when they aren't set, instead of
defaulting to `technitium-dns` / `dns.home.capilabs.dev`. The hostname is validated.
Without a terminal, all three must be passed as variables.

**Why:** The old defaults were the production server's identity, so a second server
could copy them by accident. (A first attempt made them hard-required; reverted in
favour of prompting.)

**Files:** `scripts/proxmox/create-technitium-lxc.sh`,
`docs-zensical/docs/services/technitium-dns-lxc.md`

**Follow-ups:** none new.

---

## 2026-11-08 — Technitium DNS LXC install script

**What:** Script to create a Technitium DNS Server in a new Proxmox LXC, so the
DNS server (LXC 108) can be rebuilt or a second one added in one command.

- `scripts/proxmox/create-technitium-lxc.sh`: creates an unprivileged Debian 12
  LXC on `vmbr1` + VLAN tag, runs the official Technitium installer, then uses the
  Technitium HTTP API to change the admin password, apply DNS settings (same
  defaults as the old Docker compose) and optionally restore a backup `.zip`.
- New page [Technitium DNS in an LXC](services/technitium-dns-lxc.md): usage,
  options, post-install, migration/cut-over of LXC 108, upgrades, troubleshooting.
- Linked from Services, Network → DNS, and the site nav.
- Fixed the "Database Clusters" nav entry in `zensical.toml` (newline inside an
  inline table, invalid TOML 1.0). Site builds clean with `zensical build`.

**Why:** LXC 108 was set up by hand and nothing recorded how to rebuild it.

**Tested:** `bash -n`, `shellcheck`, and a dry run with stand-ins for
`pct`/`pveam`/`pvesh`. Not yet run on a real Proxmox node.

**Files:** `scripts/proxmox/create-technitium-lxc.sh`,
`docs-zensical/docs/services/technitium-dns-lxc.md`, `docs-zensical/zensical.toml`,
`docs-zensical/docs/services/README.md`, `docs-zensical/docs/network/README.md`, `README.md`

**Follow-ups:**

- [ ] First real run on a Proxmox node; update the status note on the page.
- [ ] Confirm the VLAN 10 gateway (still `TODO` in the IP plan).
- [ ] Confirm the Infisical path for the Technitium admin password.

---

## 2026-11-08 — Documentation workflow

**What:** Set up a rule that every piece of work gets documented.

- Added `CLAUDE.md` at the repo root with documentation conventions so every
  AI-assisted session updates the docs as part of the change.
- Added this work log page and linked it in the site nav.

**Files:** `CLAUDE.md`, `docs-zensical/docs/worklog.md`, `docs-zensical/zensical.toml`

**Follow-ups:** none.
