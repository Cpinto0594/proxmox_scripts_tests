# Open items

## Problems

### Swarm: stale advertise address on `docker-dev-1`
- `docker-dev-1` advertises `192.168.1.103` internally instead of `192.168.40.10`; `docker-worker-1` drops to `Down` after manager-side events.
- `swarm init --force-new-cluster --advertise-addr` didn't take (known bug).
- Candidate fix: `docker swarm leave --force` + fresh `docker swarm init --advertise-addr 192.168.40.10`, then rejoin worker. **On hold** — requires redeploying every Dokploy stack. Decision pending.
- TODO: inventory of stacks/secrets/networks to back up before doing it.

### Headlamp unreachable via Tailscale on mobile data
- Works on WiFi/LAN. `192.168.1.0/24` subnet route advertised + approved.
- Headlamp runs on VLAN 30; if its MetalLB IP is in 192.168.1.240–250, check that the route-advertising node can actually reach it, and that the phone has "use subnet routes" on. TODO.

### Frigate
- Birdseye restream performance — try Intel Quick Sync via VAAPI / iGPU passthrough to the VM.
- Move recordings from named volume to a dedicated Proxmox virtual disk at `/mnt/frigate-storage`.

## Planned work
- [ ] Third Proxmox node: join cluster, decide on QDevice, move 3rd Patroni/Galera VMs.
- [ ] PostgreSQL HA: Patroni + etcd, 3 VMs, VLAN 40.
- [ ] MariaDB Galera ×3 + MaxScale.
- [ ] Technitium → dedicated LXC.
- [ ] Pterodactyl Panel (Dokploy) + Wings (dedicated node).
- [ ] NAS SSD cache (reuse TrueNAS boot SSD and/or SN700).
- [ ] Re-point or drop Databasus (its target `prod-postgres` is gone).
- [ ] Ansible playbook for SSH hardening across nodes.
- [ ] UPS automated shutdown.
- [ ] Export MikroTik config to repo.
- [ ] `master1`: HP Flex IO V2 2.5GbE module to replace USB adapter.
- [ ] Long term: replace mini PCs with servers.
