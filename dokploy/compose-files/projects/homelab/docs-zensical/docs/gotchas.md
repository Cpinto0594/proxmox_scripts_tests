# Gotchas

Hard-won lessons. Check here before debugging.

## Dokploy / Swarm / Traefik

- **Traefik ignores top-level `labels:` on Swarm services.** Use `deploy.labels`. Symptom: service runs fine but Traefik never routes to it (Beszel on `docker-worker-1`).
- **Dokploy Compose Type is permanent.** Plain Compose vs Swarm is set at creation. Placement constraints do nothing on a plain-Compose app. Recreate the app.
- **Dokploy "Deploy" doesn't always recreate containers.** After env/volume changes, `docker compose down && up -d` (or `docker service update --force`).
- **Swarm `mode: host` ports have no `host_ip`.** They bind on all interfaces of the node. Use a firewall to restrict.
- **`swarm init --force-new-cluster` ignores `--advertise-addr`** (known Docker bug). Stale address stays.
- **Behind Cloudflare Tunnel, no certresolver on the public router.** Cloudflare terminates TLS; use `entrypoints=web`.
- **Always set `routers.<name>.service=<name>`** explicitly, especially with multiple routers.

## Postgres

- **`POSTGRES_PASSWORD(_FILE)` only applies at `initdb`.** Reinstall + new secret + old volume = auth failure.
- **The Patroni VIP's client port is `54321`, not 5000 or 5432.** `192.168.40.120:5432` connects, but it reaches Postgres on whichever node holds the VIP, which may be a read-only replica. Always use `:54321` (HAProxy → current primary). Check the real port in `/etc/haproxy/haproxy.cfg` rather than trusting old notes.
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
- **HDMI switch EDID** breaks the OptiPlex console — use an EDID emulator.
- **Cloning a Proxmox node's disk to new hardware keeps the old NIC names.** `/etc/network/interfaces` binds `vmbr1` to a MAC-based `enx<mac>` USB adapter name, so the clone has network only because the same adapter moved with it. The onboard NIC is named differently on new hardware (`nic0` became `eno1`), so `vmbr0`'s `bridge-ports` had to be changed to `eno1`. Hostname, IPs and Tailscale state are cloned too: make sure the original machine doesn't come up under the same identity (the old `pvemaster1` was renamed `pvenode2` for this reason).
