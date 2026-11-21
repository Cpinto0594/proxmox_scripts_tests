# Gotchas

Hard-won lessons. Check here before debugging.

## Dokploy / Swarm / Traefik

- **Traefik ignores top-level `labels:` on Swarm services.** Use `deploy.labels`. Symptom: service runs fine but Traefik never routes to it (Beszel on `docker-worker-1`).
- **Dokploy Compose Type is permanent.** Plain Compose vs Swarm is set at creation. Placement constraints do nothing on a plain-Compose app. Recreate the app.
- **Dokploy "Deploy" doesn't always recreate containers.** After env/volume changes, `docker compose down && up -d` (or `docker service update --force`).
- **Swarm `mode: host` ports have no `host_ip`.** They bind on all interfaces of the node. Use a firewall to restrict.
- **`swarm init --force-new-cluster` ignores `--advertise-addr`** (known Docker bug). Stale address stays.
- **Behind Cloudflare Tunnel, no certresolver on the public router.** Cloudflare terminates TLS; use `entrypoints=web`.
- **Global services with bind mounts need the files on every node.** A bind volume is local to the node, so a config file placed on one node is missing on the other. Dozzle's replica there exited with `fatal No users.yaml or users.yml file found`. Copy the file to each node or use a Swarm `config`. (Dozzle has since moved to [authentik forward auth](services/authentik-forward-auth.md), so it no longer needs the file.)
- **Always set `routers.<name>.service=<name>`** explicitly, especially with multiple routers.
- **authentik forward auth returns authentik's 404 page** when the embedded outpost has no provider for the host. The app's URL then shows a broken authentik page (404s for `/static/dist/...`). Creating the provider and application isn't enough: add the application to **Outposts → authentik Embedded Outpost**. See [authentik forward auth](services/authentik-forward-auth.md#troubleshooting).
- **Don't copy the routers from authentik's Traefik example** (`default-router` → `http://ip.internal`, outpost service URL ending in `/outpost.goauthentik.io`). They're placeholders that take over the app's hostname and double the outpost path.
- **Every router of a header-trusting app needs the auth middleware.** Dozzle `forward-proxy` trusts `X-Authentik-*`; a router without `authentik@file` lets anyone set those headers themselves.
- **authentik 2025.10+ sends `email_verified: false` by default.** Apps that require a verified email (Beszel / PocketBase) reject the OIDC login. Add a custom Scope Mapping with scope name `email` that returns `email_verified: True`, and remove the default `email` mapping from the provider, or it can still win. See [Beszel step 1](services/beszel.md#step-1-email-verified-scope-mapping-in-authentik).
- **Traefik logs router errors only when its config changes.** An old `service ... does not exist` stays in `docker logs` after the fix. Check with `--since`.
- **The Traefik container's tools are busybox.** `wget` has no `--max-redirect` (and with `2>&1 | grep` the error disappears silently). `nslookup` prints `NXDOMAIN` for the Tailscale search-domain attempt even when the bare name resolves.

## Postgres

- **`POSTGRES_PASSWORD(_FILE)` only applies at `initdb`.** Reinstall + new secret + old volume = auth failure.
- **The Patroni VIP's client port is `54321`, not 5000 or 5432.** `192.168.40.120:5432` connects, but it reaches Postgres on whichever node holds the VIP, which may be a read-only replica. Always use `:54321` (HAProxy → current primary). Check the real port in `/etc/haproxy/haproxy.cfg` rather than trusting old notes.
- **Every role can `CONNECT` to every database by default** (granted to `PUBLIC`). `REVOKE ALL ON DATABASE app FROM PUBLIC` only keeps others out of `app`; it doesn't keep the app role out of the other databases. Revoke `CONNECT` from `PUBLIC` on all databases (loop in [authentik → Keep authentik out of every other database](services/authentik.md#keep-authentik-out-of-every-other-database)).
- **HAProxy in front of Postgres needs long timeouts.** Ubuntu's `defaults` have `timeout client/server 50000` (50 s) and kill idle pooled connections. Set `timeout client 30m` and `timeout server 30m` in the `listen` block.

## VMs / disks

- **Cloned VMs share SSH host keys.** `pg1`–`pg3` (and so the VIP) all present the same ed25519 host key, so you can't tell nodes apart by key and a MITM wouldn't be noticed. Regenerate per VM: `sudo rm /etc/ssh/ssh_host_* && sudo dpkg-reconfigure openssh-server && sudo systemctl restart ssh`. Do it in the template (or with `cloud-init`) for future clones.
- **Ubuntu installer under-allocates LVM root.** Check `lsblk` after provisioning any VM.

## Kubernetes

- Disable swap before kubeadm.
- Load `br_netfilter` on every node, persistently.
- Pod CIDR must not overlap any LAN/VLAN subnet.

## Proxmox / storage / network

- **OptiPlex onboard NIC is 1G only**; USB RTL8156 adapters do a real 2.35 Gbit/s.
- **Client-side VPN can hijack LAN traffic.** A NAS web UI that looked "unreachable" was actually a VPN on the laptop intercepting the traffic. Check this first.
- **Bridge names must match across Proxmox nodes for migration.** Guests attach to `vmbr1`; a node installed with a differently named bridge (`pvenode2` initially had `vmbr0`) can't receive them. Use `vmbr1` for the USB-adapter bridge on every node.
- **`*.home.capilabs.dev` also resolves publicly, to Cloudflare.** A host not using Technitium gets Cloudflare's IPs, and Cloudflare has no certificate for that name, so TLS fails with `SSL alert number 40` / `handshake failure` (seen on the Proxmox OpenID realm pointing at authentik). Point the host's DNS at `192.168.10.2`. Test: `getent hosts authentik.home.capilabs.dev` must return `192.168.40.10`. See [authentik → Proxmox VE login](services/authentik.md#proxmox-ve-login-openid-connect-realm).
- **HDMI switch EDID** breaks the OptiPlex console — use an EDID emulator.
- **Cloning a Proxmox node's disk to new hardware keeps the old NIC names.** `/etc/network/interfaces` binds `vmbr1` to a MAC-based `enx<mac>` USB adapter name, so the clone has network only because the same adapter moved with it. The onboard NIC is named differently on new hardware (`nic0` became `eno1`), so `vmbr0`'s `bridge-ports` had to be changed to `eno1`. Hostname, IPs and Tailscale state are cloned too: make sure the original machine doesn't come up under the same identity (the old `pvemaster1` was renamed `pvenode2` for this reason).
