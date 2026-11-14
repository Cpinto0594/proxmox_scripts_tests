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
- [ ] Deploy [authentik](services/authentik.md) on `docker-worker-1`, then move Forgejo / Portainer / Dozzle / Beszel logins to SSO.
- [ ] MariaDB Galera ×3 + MaxScale.
- [ ] UPS automated shutdown.
- [ ] Long term: replace mini PCs with servers.
