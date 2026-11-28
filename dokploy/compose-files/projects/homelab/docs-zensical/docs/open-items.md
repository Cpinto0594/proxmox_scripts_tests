# Open items

## Problems

### Swarm: stale advertise address on `docker-dev-1`
- `docker-dev-1` advertises a stale address internally (matching none of its interfaces) instead of `192.168.40.10`; `docker-worker-1` drops to `Down` after manager-side events.
- `swarm init --force-new-cluster --advertise-addr` didn't take (known bug).
- Candidate fix: `docker swarm leave --force` + fresh `docker swarm init --advertise-addr 192.168.40.10`, then rejoin worker. **On hold** — requires redeploying every Dokploy stack. Decision pending.
- TODO: inventory of stacks/secrets/networks to back up before doing it.

### Headlamp unreachable via Tailscale on mobile data
- Works on WiFi/LAN. MetalLB hands out IPs from 192.168.30.210–250 (VLAN 30).
- Fix in progress: advertise VLANs 10/30/40 from both Proxmox hosts, approve the routes, add split DNS. Close this item once Headlamp and a `*.home.capilabs.dev` app load from a phone on mobile data.

## Planned work
- [ ] Patroni HAProxy: add `option tcplog`, `timeout client 30m`, `timeout server 30m` to `listen postgres_primary` on `pg1`–`pg3` (stock 50 s timeouts drop idle connections). See [guide 3.6](services/patroni-cluster-guide.md#36-haproxy-all-three).
- [ ] Regenerate SSH host keys on `pg1`–`pg3`: all three share one key (cloned VMs). See [gotchas](gotchas.md#vms-disks).
- [ ] Patroni cluster is now the main Postgres: review hardening (TLS, `scram-sha-256` in `pg_hba`, Databasus backups of each app DB, monitoring). TODO: check what is already done.
- [ ] Move Forgejo / Portainer logins to [authentik](services/authentik.md) SSO (OIDC where the app supports it, otherwise [forward auth](services/authentik-forward-auth.md)). Dozzle is done; Beszel is set up (below).
- [ ] Beszel OIDC: confirm login on the public and local URLs, record the scope-mapping option and authentik hostnames used, then set `DISABLE_PASSWORD_AUTH=true`. See [Beszel](services/beszel.md#authentication-authentik-oidc).
- [ ] Dozzle SSO: confirm the public provider/login (`dozzle.homelab.capilabs.dev`), bind an admin group to the Dozzle applications, delete the old `users.yml` on both nodes. See [Dozzle](services/dozzle.md#authentication-authentik-sso).
- [ ] Fill the `TODO:`s on the new app pages: Termix stack name / deployed? ([Termix](services/termix.md)), `forgejo-runner2` on `docker-dev-1` ([Forgejo](services/forgejo.md#runners)), cloudflared compose uses `infra-network` but declares `dokploy-network` ([Cloudflare Tunnel](services/cloudflared.md)), `init-db-script.sh` missing from the repo ([Databasus](services/databasus.md#add-a-backup-user-to-a-database)).
- [ ] Wake-on-LAN (configured on all nodes 2026-11-27, NICs on VLAN 40, wake from power-off works on each node): record the exact BIOS setting names, and paste each node's `/etc/network/interfaces` and check output (the docs were written from the planned change). See [Wake-on-LAN](network/usb-2.5g-adapters.md#wake-on-lan-onboard-nics).
- [ ] SODOLA switch: ports and MACs recorded (2026-11-27, see [SODOLA port map](inventory/hardware.md#sodola-port-map)). VLANs set 2026-11-27 (ports 1–3 access VLAN 40, port 8 / `ether8` trunk with VLAN 40 tagged). Still to do: record what's on ports 4–7, and decide whether to trunk VLANs 10–40 so the onboard NICs work for failback (test WoL with tagged frames first).
- [ ] Future enhancement: active-backup bond (USB 2.5G primary, onboard 1G standby) under `vmbr1` on each Proxmox host, for automatic NIC failover. Needs the SODOLA port and uplink trunked for VLANs 10–40 first. See [active-backup bond](network/usb-2.5g-adapters.md#future-enhancement-active-backup-bond).
- [ ] MariaDB Galera ×3 + MaxScale.
- [ ] Comet X KVM: record which host is on each port, its switch port and power source, static vs DHCP, the DNS record and cert for `kvm.home.capilabs.dev`, whether the OptiPlex console works through it, remote access (VLAN 1 isn't on Tailscale), and store the admin password in Infisical. See [hardware](inventory/hardware.md#remote-management-kvm).
- [ ] UPS automated shutdown.
- [ ] Long term: replace mini PCs with servers.
