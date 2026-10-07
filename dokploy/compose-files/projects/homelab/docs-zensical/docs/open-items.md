# Open items

## Problems

### Home Assistant and Frigate not found
- Neither is running on `docker-dev-1` or `docker-worker-1`. TODO: confirm whether they were removed or moved. The Frigate open item below and the Tapo-plug dashboard depend on this.


### Swarm: stale advertise address on `docker-dev-1`
- `docker-dev-1` advertises a stale address internally (matching none of its interfaces) instead of `192.168.40.10`; `docker-worker-1` drops to `Down` after manager-side events.
- `swarm init --force-new-cluster --advertise-addr` didn't take (known bug).
- Candidate fix: `docker swarm leave --force` + fresh `docker swarm init --advertise-addr 192.168.40.10`, then rejoin worker. **On hold** — requires redeploying every Dokploy stack. Decision pending.
- TODO: inventory of stacks/secrets/networks to back up before doing it.

### Headlamp unreachable via Tailscale on mobile data
- Works on WiFi/LAN. MetalLB hands out IPs from 192.168.30.210–250 (VLAN 30).
- Fix in progress: advertise VLANs 10/30/40 from both Proxmox hosts, approve the routes, add split DNS. Close this item once Headlamp and a `*.home.capilabs.dev` app load from a phone on mobile data.

### Frigate
- Birdseye restream performance — try Intel Quick Sync via VAAPI / iGPU passthrough to the VM.
- Move recordings from named volume to a dedicated Proxmox virtual disk at `/mnt/frigate-storage`.

## Planned work
- [ ] Third Proxmox node: join cluster, decide on QDevice, move VM 106 (`pg.patroni.vm3`) and the 3rd Galera VM.
- [ ] Rebalance guests: split Patroni VMs 101/105 across hosts, put one k8s worker on `pvemaster1`, consider shrinking `k8s-master1` to 4 GB.
- [ ] Rename Proxmox VMs 104 → `docker-dev-1`, 107 → `docker-worker-1`.
- [ ] PostgreSQL HA: Patroni + etcd — VMs 101/105/106 created on VLAN 40, not yet running.
- [ ] MariaDB Galera ×3 + MaxScale.
- [x] Technitium → dedicated LXC (LXC 108). TODO: confirm the old Docker Compose instance on `docker-dev-1` is removed.
- [ ] Pterodactyl Panel (Dokploy) + Wings (dedicated node).
- [ ] NAS SSD cache (spare 256 GB M.2 and/or SN700).
- [ ] Ansible playbook for SSH hardening across nodes.
- [ ] UPS automated shutdown.
- [ ] Export MikroTik config to repo.
- [ ] `pvemaster1`: HP Flex IO V2 2.5GbE module to replace USB adapter.
- [ ] Long term: replace mini PCs with servers.
