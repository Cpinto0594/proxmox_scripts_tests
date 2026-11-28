# Work log

Chronological record of work done on the homelab and this repo, newest first.
Each entry: what changed, why, files touched, and follow-ups. Keep the detailed
"how" on the relevant topic page and link to it from here.

---

## 2026-11-27 — UpSnap added; onboard WoL NICs moved to VLAN 40

**What:** Added [UpSnap](services/upsnap.md), a Wake-on-LAN dashboard, on `docker-dev-1` as a
Dokploy Compose app (type **Docker Compose**, `network_mode: host`, listening on
`192.168.40.10:8090`). Traefik routes `upsnap.home.capilabs.dev` to it through a new file-provider
config (`dokploy/traefik/dynamic/upsnap.yml`), because labels can't route to a host-network
container. Local only, no public router.

UpSnap's network scan found nothing: scanning `192.168.1.0/24` from VLAN 40 sees hosts but no
MACs (ARP doesn't cross the router), so the nodes were added by hand with their onboard-NIC MACs.
Waking then worked from the MikroTik (`/tool wol`) but not from UpSnap, because the magic packet is
a broadcast and the MikroTik doesn't forward it from VLAN 40 into VLAN 1. A static-ARP relay on the
MikroTik was considered and dropped; instead the onboard NICs were moved into VLAN 40:

- MikroTik `ether8`: added as tagged on VLAN 40 (PVID 1 unchanged). Equivalent command:
  `/interface bridge vlan set [find vlan-ids=40] tagged=bridge,ether2,ether3,ether4,ether8`.
- SODOLA port 8: Trunk, Native VLAN 1, Trunk vlan 1 + 40. It was briefly set to Access VLAN 40,
  which mixes VLAN 1 into 40; corrected.
- SODOLA ports 1–3: Access VLAN 40.
- UpSnap devices use the nodes' VLAN 40 addresses so the wake goes to `192.168.40.255`.

The three nodes are in UpSnap with their VLAN 40 addresses (`192.168.40.5`–`.7`), and a wake from
power-off worked on each node. Dokploy app `Upsnap`; image kept on the `:5` tag; Technitium record
`upsnap.home.capilabs.dev` exists; `LOCAL_DOMAIN` kept in `.env.sample` as a note. `pvemaster1` can't be woken from UpSnap
(it hosts `docker-dev-1`); use `/tool wol interface=vlan-40` on the MikroTik. The `etherwake`
examples now use `vmbr1.40`.

**Why:** Wake the Proxmox nodes from a web UI instead of the MikroTik CLI.

**Files:** `dokploy/compose-files/projects/homelab/upsnap/compose.yml`,
`dokploy/compose-files/projects/homelab/upsnap/.env.sample`, `dokploy/traefik/dynamic/upsnap.yml`,
`docs-zensical/zensical.toml`, `docs-zensical/docs/services/upsnap.md` (new),
`docs-zensical/docs/services/README.md`, `docs-zensical/docs/network/usb-2.5g-adapters.md`,
`docs-zensical/docs/network/README.md`, `docs-zensical/docs/inventory/hardware.md`,
`docs-zensical/docs/inventory/ip-plan.md`, `docs-zensical/docs/gotchas.md`,
`docs-zensical/docs/open-items.md`, `docs-zensical/docs/worklog.md`

MikroTik VLAN 40 configured list checked: `tagged=ether2,ether3,ether4,bridge,ether8`.

**Follow-ups:** the BIOS setting names (see [open items](open-items.md)).

---

## 2026-11-27 — `pvemaster1` upgraded to 32 GB RAM

**What:** Second 16 GB DDR5 module added to `pvemaster1` (HP Elite Mini 800 G9), from 16 GB to
32 GB. All three nodes now have 32 GB.

**Why:** `pvemaster1` was the tight node (10.4 of 15 GB in use) and couldn't take another node's
guests on failure.

**Files:** `docs-zensical/docs/inventory/hardware.md`, `docs-zensical/docs/platforms/proxmox.md`,
`docs-zensical/docs/worklog.md`

**Follow-ups:** confirm usable RAM and speed on the host and refresh the capacity table:

```bash
free -g
dmidecode -t memory | grep -E "Size|Speed" | grep -v "No Module"
pvesh get /cluster/resources --type node
```

---

## 2026-11-27 — Onboard NICs set up for Wake-on-LAN (all nodes)

**What:** The owner cabled and enabled `pvemaster1`'s onboard 1G NIC (`eno1`). It was first set
up with `192.168.1.100/24` and a second `gateway` on `vmbr0`. Reviewing the interfaces file found
two problems: two interfaces on the same /24 (one default route survives, ARP flux, traffic can
quietly use the 1G link), and the Wake-on-LAN `post-up` attached to `vmbr1.40`. The NIC is only
for Wake-on-LAN, so the owner applied the fix: no IP or gateway on `vmbr0`, and
`post-up ethtool -s eno1 wol g` under `auto eno1`. The onboard 1G ports are cabled to the SODOLA
switch, not the MikroTik. Documented the new config, a
[Wake-on-LAN](network/usb-2.5g-adapters.md#wake-on-lan-onboard-nics) section (check,
BIOS, `etherwake` test), the SODOLA cabling, and what it means for failback. Also added two
gotchas.

**Why:** Wake `pvemaster1` remotely from power-off. The USB adapter can't be relied on for that.

**Files:** `docs-zensical/docs/network/usb-2.5g-adapters.md`, `docs-zensical/docs/network/README.md`,
`docs-zensical/docs/inventory/ip-plan.md`, `docs-zensical/docs/inventory/hardware.md`,
`docs-zensical/docs/platforms/proxmox.md`, `docs-zensical/docs/gotchas.md`,
`docs-zensical/docs/open-items.md`, `docs-zensical/docs/worklog.md`

Also documented an active-backup bond (USB primary, onboard standby) as a
[future enhancement](network/usb-2.5g-adapters.md#future-enhancement-active-backup-bond): the
config, the switch-side VLAN changes, apply and test steps, and caveats. Not applied.

Recorded the SODOLA cabling from the owner: onboard NICs on SODOLA ports 1–3 (`pvemaster1`
`7c:57:58:5d:a2:e4`, `pvenode1` `20:88:10:97:b9:44`, `pvenode2` `30:13:8b:81:e4:a8`), and the
SODOLA uplink from its port 8 to MikroTik `ether8`. Added a
[SODOLA port map](inventory/hardware.md#sodola-port-map), updated the MikroTik port map (`ether8`),
and filled the port and MAC placeholders in the WoL and bond sections.

Reworked the [Compute](inventory/hardware.md#compute) table in the hardware inventory. It now
has one row per host (model, CPU, RAM, role) and a separate
[Network interfaces](inventory/hardware.md#network-interfaces) table with one row per NIC
(interface, chipset/driver, MAC, switch port, use). The notes below each table are now bullets in
the same style.

The owner then applied the same fix on `pvenode1` and `pvenode2`: no IP on `vmbr0`, and
`post-up ethtool -s nic0 wol g` under `auto nic0`. Rewrote their config tabs from the pasted files
plus that change, and made the Wake-on-LAN section cover all three nodes (MACs, SODOLA ports,
BIOS, `etherwake` per node). Recorded that `pvenode2` now has a `vmbr0` fallback and its adapter
shows as `enx6c1ff7cd73e3`. Closed the "re-document pvenode1/pvenode2" open item.

**Follow-ups:** paste the applied `/etc/network/interfaces` and the check output (the doc was
written from the planned change), check the VLANs on the SODOLA ports and `ether8`, set the BIOS and test a
wake from power-off on each node (see [open items](open-items.md)). Couldn't
verify live: SSH from the workstation to `192.168.1.90` was refused (no key).

---

## 2026-11-27 — GL.iNet Comet X KVM added to the inventory (docs)

**What:** Added the GL.iNet Comet X (GL-RM4PE) quad-port IP KVM to the hardware inventory (new
[Remote management (KVM)](inventory/hardware.md#remote-management-kvm) section) and to the
[IP plan](inventory/ip-plan.md#infrastructure): `192.168.1.79` on VLAN 1, web UI at
`kvm.home.capilabs.dev`. Specs taken from GL.iNet's product page. Noted that VLAN 1 isn't on the
Tailscale routes, so the KVM can't be reached remotely as things stand.

**Why:** New device in the homelab; it gives remote console/BIOS access to the Proxmox nodes.

**Files:** `docs-zensical/docs/inventory/hardware.md`, `docs-zensical/docs/inventory/ip-plan.md`,
`docs-zensical/docs/open-items.md`, `docs-zensical/docs/worklog.md`

**Follow-ups:** port-to-host mapping, switch port and power source, static vs DHCP, the DNS
record and certificate, OptiPlex EDID through the KVM, remote access, and the admin password in
Infisical (see [open items](open-items.md)). Couldn't verify anything live: from the workstation
(WSL), `kvm.home.capilabs.dev` resolved through public DNS and `192.168.1.79` didn't answer ping.

---

## 2026-11-25 — Apps dropdown in the docs nav (docs)

**What:** Added an **Apps** section under Services in the sidebar, one entry per app with a
compose file in `dokploy/compose-files/projects/homelab/` (GitLab left out, it's retired).
Wrote the missing app pages from the compose files: Forgejo, Infisical, Portainer, Databasus,
Cloudflare Tunnel, Docs site, Termix. Linked them from the [service catalog](services/README.md)
and added a Termix row there.

**Why:** Easier to find an app's page as the number of services grows.

**Files:** `docs-zensical/zensical.toml`, `docs-zensical/docs/services/{forgejo,infisical,portainer,databasus,cloudflared,docs-site,termix}.md` (new),
`docs-zensical/docs/services/README.md`, `docs-zensical/docs/open-items.md`, `docs-zensical/docs/worklog.md`

**Follow-ups:** the new pages carry `TODO:`s, mainly: Termix stack name and whether it's
deployed, `forgejo-runner2` on `docker-dev-1`, Infisical paths for the app secrets, the
`infra-network` mismatch in the cloudflared compose file, and the missing `init-db-script.sh`
for Databasus. `technitium/compose.yml` is unused (Technitium runs in LXC 108); the nav entry
points to the LXC page.

---

## 2026-11-20 — Beszel login through authentik OIDC (docs)

**What:** Documented the Beszel ↔ authentik OpenID Connect setup on a new [Beszel](services/beszel.md)
page: the custom `email` scope mapping that sends `email_verified: true`, the OAuth2/OpenID
provider and application, the OpenID Connect provider in PocketBase (`/_/`), user creation
(`USER_CREATION=true`, already in `compose.yml`) and `DISABLE_PASSWORD_AUTH`, plus checks. Added
notes for this homelab: register a redirect URI for both Beszel hostnames, and use the public
authentik host for the Auth URL (and for the token/userinfo URLs unless `docker-worker-1`
resolves through Technitium).

**Why:** Part of moving app logins to authentik. authentik 2025.10+ sends `email_verified: false`
by default, which Beszel rejects, so the setup has a non-obvious step.

**Files:** `docs-zensical/docs/services/beszel.md` (new), `docs-zensical/zensical.toml`,
`docs-zensical/docs/services/README.md`, `docs-zensical/docs/services/authentik.md`,
`docs-zensical/docs/gotchas.md`, `docs-zensical/docs/open-items.md`,
`docs-zensical/docs/worklog.md`

**Follow-ups:** confirm login on both URLs, record the scope-mapping option and authentik
hostnames used, store the client secret in Infisical, then set `DISABLE_PASSWORD_AUTH=true`
(see [open items](open-items.md)).

---

## 2026-11-21 — Dozzle login through authentik forward auth

**What:** Replaced Dozzle's `simple` auth (`users.yml` on each node) with authentik SSO. Traefik
forward auth goes through authentik's embedded outpost, and Dozzle runs with
`DOZZLE_AUTH_PROVIDER=forward-proxy` and reads the `X-Authentik-*` headers. Added
`dokploy/traefik/dynamic/authentik-fw.yml` (middlewares `authentik`, `forwarded-https` and service
`authentik-outpost`) and installed it in `/etc/dokploy/traefik/dynamic/` on `docker-dev-1`. Put
`authentik@file` on both Dozzle routers, added `dozzle-outpost-public` / `dozzle-outpost-local` for
`/outpost.goauthentik.io/*`, and created the `dozzle-local` proxy provider + application. Login
on `https://dozzle.home.capilabs.dev` works.

Problems on the way:

- The first version of the Traefik file carried the placeholder routers from authentik's docs
  example (`default-router` → `http://ip.internal`, outpost URL with the path doubled). Removed.
- `authentik-outpost@file does not exist`: the server copy of the file was older than the repo.
- The app URL showed authentik's 404 page because the application wasn't in the Embedded Outpost.
  Adding it fixed the login.
- `context canceled` on the forward-auth call was the browser aborting requests. Traefik reaches
  authentik fine through both the service VIP and `tasks.<service>`.

**Why:** No per-node `users.yml` to keep in sync on a global service, and one login for the
homelab. First step of moving app logins to authentik.

**Files:** `dokploy/traefik/dynamic/authentik-fw.yml`,
`dokploy/compose-files/projects/homelab/dozzle/compose.yml`,
`docs-zensical/docs/services/authentik-forward-auth.md` (new),
`docs-zensical/docs/services/dozzle.md`, `docs-zensical/docs/services/authentik.md`,
`docs-zensical/docs/services/README.md`, `docs-zensical/docs/gotchas.md`,
`docs-zensical/docs/open-items.md`, `docs-zensical/zensical.toml`,
`docs-zensical/docs/worklog.md`

**Follow-ups:**

- [ ] Create or confirm the `dozzle-public` provider/application, and test a login on `https://dozzle.homelab.capilabs.dev`.
- [ ] Bind an admin group to the Dozzle applications.
- [ ] Delete the old `users.yml` from `/mnt/docker-storage/dozzle/` on both nodes.
- [ ] Pin the Dozzle image to a version tag.

---

## 2026-11-17 — MikroTik addresses and VLAN gateways

**What:** Filled in the VLAN 10–40 gateways in the IP plan from `/ip address print` on the
MikroTik: `192.168.10.1`, `.20.1`, `.30.1`, `.40.1` on `vlan-10`–`vlan-40`. `192.168.1.2` is a
static address on `bridge`, used only for management; VLAN 1's gateway stays the home router
(`192.168.1.1`). Added the full address table to the IP plan and a pointer from the switch port map.

**Why:** The gateways were `TODO` in the IP plan.

**Files:** `docs-zensical/docs/inventory/ip-plan.md`, `docs-zensical/docs/inventory/hardware.md`,
`docs-zensical/docs/worklog.md`

**Follow-ups:**

- [ ] The switch labels VLAN 10 `MNT`, the docs call it `MGMT`. Pick one.

---

## 2026-11-17 — Second Technitium DNS server (Secondary) in the inventory

**What:** Recorded the Technitium cluster Secondary at `192.168.10.3`. Checked from the
workstation: it answers DNS and serves the web console on :5380, same as the Primary. Added it to
the IP plan, the Proxmox guest table (placeholder row), the network DNS section and the
Technitium page (current cluster, console table), and removed the "TODO: real IP" notes there.
Couldn't read the CTID / node: SSH to the nodes was refused (no key) and `pvenode2` timed out.

**Why:** The Secondary was running but its address wasn't documented.

**Files:** `docs-zensical/docs/inventory/ip-plan.md`, `docs-zensical/docs/platforms/proxmox.md`,
`docs-zensical/docs/network/README.md`, `docs-zensical/docs/services/technitium-dns-lxc.md`,
`docs-zensical/docs/worklog.md`

**Follow-ups:**

- [ ] Fill in the Secondary's CTID, node and resources (`pct list` on each node).
- [ ] Remove the `# TODO: set to the second server's real IP` comment in `dokploy/traefik/dynamic/technitium-lxc.yml` (the IP is right).
- [ ] Add `192.168.10.3` as the second resolver in DHCP and Tailscale split DNS, if not already.

---

## 2026-11-17 — Network device IPs: SODOLA switch and MikroTik

**What:** Documented a new network device: SODOLA SL902-SWTGW218AS managed switch, management
IP `192.168.1.3` (VLAN 1). Also recorded the MikroTik CRS310-8G+2S+IN management IP,
`192.168.1.2` (VLAN 1). Added both to the hardware inventory, the IP plan (infrastructure static
assignments) and the network layout.

**Why:** Keep the inventory complete; the network devices' management IPs weren't written down.

**Files:** `docs-zensical/docs/inventory/hardware.md`, `docs-zensical/docs/inventory/ip-plan.md`,
`docs-zensical/docs/network/README.md`, `docs-zensical/docs/worklog.md`

**Follow-ups:**

- [ ] Confirm the switch's port layout, role, and the MikroTik port it uplinks to (then update the [switch port map](inventory/hardware.md#switch-port-map)).
- [ ] Document its VLAN config and connected devices.
- [ ] Store the SODOLA and MikroTik admin passwords in Infisical.
- [x] Record the MikroTik's IPs on VLANs 10–40 and fill the gateway `TODO`s in the IP plan (done, see the entry above).

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
