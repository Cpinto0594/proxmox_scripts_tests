# Gotchas

Hard-won lessons. Check here before debugging.

## Dokploy / Swarm / Traefik

- **Traefik ignores top-level `labels:` on Swarm services.** Use `deploy.labels`. Symptom: service runs fine but Traefik never routes to it (Beszel on `docker-worker-1`).
- **Dokploy Compose Type is permanent.** Plain Compose vs Swarm is set at creation. Placement constraints do nothing on a plain-Compose app (Home Assistant landed on the wrong node). Recreate the app.
- **Dokploy "Deploy" doesn't always recreate containers.** After env/volume changes, `docker compose down && up -d` (or `docker service update --force`).
- **Swarm `mode: host` ports have no `host_ip`.** They bind on all interfaces of the node. Use a firewall to restrict.
- **`swarm init --force-new-cluster` ignores `--advertise-addr`** (known Docker bug). Stale address stays.
- **Behind Cloudflare Tunnel, no certresolver on the public router.** Cloudflare terminates TLS; use `entrypoints=web`.
- **Always set `routers.<name>.service=<name>`** explicitly, especially with multiple routers.

## Postgres

- **`POSTGRES_PASSWORD(_FILE)` only applies at `initdb`.** Reinstall + new secret + old volume = auth failure. See [runbook](runbooks/postgres-password-mismatch.md).

## VMs / disks

- **Ubuntu installer under-allocates LVM root.** Check `lsblk` after provisioning any VM. See [runbook](runbooks/extend-lvm-root.md).

## Kubernetes

- Disable swap before kubeadm.
- Load `br_netfilter` on every node, persistently.
- Pod CIDR must not overlap any LAN/VLAN subnet.

## Proxmox / storage / network

- **QDevice needs Tailscale on the host OS**, not in a VM.
- **`exportfs` fails on unresolvable hostnames** — use IPs or `/etc/hosts`.
- **OptiPlex onboard NIC is 1G only**; USB RTL8156 adapters do a real 2.35 Gbit/s.
- **Client-side VPN can hijack LAN traffic.** TrueNAS UI "unreachable" was a VPN on the laptop. Check this first.
- **HDMI switch EDID** breaks the OptiPlex console — use an EDID emulator.
