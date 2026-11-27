# IP plan

## VLANs

| VLAN | Subnet | Purpose | Gateway |
|---|---|---|---|
| 1 | 192.168.1.0/24 | DEFAULT — main LAN, Proxmox host IPs, home router uplink | 192.168.1.1 |
| 10 | 192.168.10.0/24 | MGMT — infra services (DNS) | 192.168.10.1 (MikroTik `vlan-10`) |
| 20 | 192.168.20.0/24 | NAS — storage | 192.168.20.1 (MikroTik `vlan-20`) |
| 30 | 192.168.30.0/24 | K8S — Kubernetes | 192.168.30.1 (MikroTik `vlan-30`) |
| 40 | 192.168.40.0/24 | APPS — Docker / Dokploy, DB clusters | 192.168.40.1 (MikroTik `vlan-40`) |

Inter-VLAN routing is on the MikroTik (confirmed working at least between VLAN 1 and VLAN 10).
On VLAN 1 the MikroTik is not the gateway: it has `192.168.1.2` on `bridge` for management only, and
the home router at `192.168.1.1` is the gateway.

MikroTik addresses, from `/ip address print` (2026-11-17), all static:

| Address | Interface | Comment on the switch |
|---|---|---|
| 192.168.1.2/24 | `bridge` | Switch mgmt on existing LAN |
| 192.168.10.1/24 | `vlan-10` | VLAN-10 - MNT |
| 192.168.20.1/24 | `vlan-20` | VLAN-20 - NAS |
| 192.168.30.1/24 | `vlan-30` | VLAN-30 - K8S |
| 192.168.40.1/24 | `vlan-40` | VLAN40 - APPS |

```bash
# on the MikroTik
/ip address print
```

## Static assignments

### Proxmox hosts

On all three nodes, host IPs live on `vmbr1` (USB 2.5G adapter) and its VLAN sub-interfaces. `vmbr0` (onboard 1G) and `vmbr0.10/.20/.30/.40` exist on every node as a fallback with no IPs.

| Host | VLAN 1 (`vmbr1`) | VLAN 10 (`vmbr1.10`) | VLAN 20 (`vmbr1.20`) | VLAN 30 (`vmbr1.30`) | VLAN 40 (`vmbr1.40`) | Switch port |
|---|---|---|---|---|---|---|
| `pvemaster1` | 192.168.1.90 | 192.168.10.5 | 192.168.20.5 | 192.168.30.5 | 192.168.40.5 | ether2 |
| `pvenode1` | 192.168.1.91 | 192.168.10.6 | 192.168.20.6 | 192.168.30.6 | 192.168.40.6 | ether3 |
| `pvenode2` | 192.168.1.92 | 192.168.10.7 | 192.168.20.7 | 192.168.30.7 | 192.168.40.7 | ether4 |

**Onboard NIC (`vmbr0`):** no IPs. The onboard NICs are cabled to the SODOLA for [Wake-on-LAN](../network/usb-2.5g-adapters.md#wake-on-lan-onboard-nics) only. They briefly had `192.168.1.100`–`.102` on 2026-11-27, removed the same day on all three nodes.

All subnets are /24. Pattern: each new node takes the previous node's addresses +1 — `.90`, `.91`, `.92` on VLAN 1 and `.5`, `.6`, `.7` on VLANs 10–40. `pvenode2` is the third node.

!!! note "Hardware swap (2026-10-27)"
    The third node arrived as new hardware. The disk of the old `pvemaster1` (HP Pro Mini 400 G9) was cloned onto it, so the new machine **is now `pvemaster1`** and keeps `.90` / `.5`. The old HP Pro Mini was renamed **`pvenode2`** and took the third-node addresses (`.92` / `.7`). The guests on `pvemaster1` moved with the disk. Both machines have been checked on the hosts (2026-10-27): `pvemaster1` has `.1.90` on `vmbr1` plus `.10.5`–`.40.5` on `vmbr1.10`–`.40`; `pvenode2` has `.1.92` on `vmbr1` plus `.10.7`–`.40.7` on `vmbr1.10`–`.40`. Switch ports: `pvemaster1` on `ether2`, `pvenode1` on `ether3`, `pvenode2` on `ether4` (see [switch port map](hardware.md#switch-port-map)).

### Infrastructure

| Name | IP | Notes |
|---|---|---|
| MikroTik CRS310-8G+2S+IN | 192.168.1.2 | Core switch/router, management (WebFig/Winbox/SSH). Static, on `bridge`. Also the gateway (`.1`) on VLANs 10–40, see [VLANs](#vlans) |
| SODOLA SL902-SWTGW218AS | 192.168.1.3 | Managed switch, web UI. TODO: confirm static vs DHCP reservation |
| Technitium DNS (Primary) | 192.168.10.2 | LXC 108 on `pvemaster1`, `dns1.home.capilabs.dev` |
| Technitium DNS (Secondary) | 192.168.10.3 | Cluster replica, `dns2.home.capilabs.dev`. Answers DNS and serves the console on :5380 (checked 2026-11-17). TODO: CTID and node |
| DXP2800 (UGOS) | 192.168.20.2 | NFS |
| GL.iNet Comet X (GL-RM4PE) KVM | 192.168.1.79 | Quad-port IP KVM, `kvm.home.capilabs.dev`. VLAN 1, so not on the Tailscale routes. TODO: confirm static vs DHCP reservation. See [hardware](hardware.md#remote-management-kvm) |

### Kubernetes (VLAN 30)

| Name | IP |
|---|---|
| `k8s-master1` | 192.168.30.10 |
| `k8s-worker1` | 192.168.30.11 |
| `k8s-worker2` | 192.168.30.12 |
| MetalLB pool | 192.168.30.210–192.168.30.250 (`metallb_addresses` in Terragrunt) |

### Docker / Apps (VLAN 40)

| Name | IP | Notes |
|---|---|---|
| `docker-dev-1` | 192.168.40.10 | Swarm manager, Dokploy |
| `docker-worker-1` | 192.168.40.11 | Swarm worker |
| `pg1` | 192.168.40.115 | Patroni / Postgres / etcd / HAProxy |
| `pg2` | 192.168.40.116 | same |
| `pg3` | 192.168.40.117 | same |
| Postgres VIP (keepalived) | 192.168.40.120 | Clients use port 54321 (HAProxy → primary) |
| Galera VMs + MaxScale | TODO | Planned |

## Tailscale

### Infrastructure nodes

| Node | Tailscale IP | Why it's on the tailnet |
|---|---|---|
| `pvemaster1` | 100.64.117.20 (unchanged after the disk clone, checked 2026-10-27) | Proxmox node, advertises VLAN routes |
| `pvenode1` | 100.68.240.6 | Proxmox node, advertises VLAN routes |
| `pvenode2` | 100.108.252.11 | Proxmox node, advertises VLAN routes |
| `docker-dev-1` | 100.64.122.124 | Swarm manager / Dokploy admin access |
| `docker-worker-1` | 100.69.115.109 | Swarm worker admin access |

### Client devices

| Device | Tailscale IP | OS |
|---|---|---|
| `desktop-ep0ql4s` | 100.115.59.61 | Windows |
| `desktop-ep0ql4s-1` | 100.85.105.66 | Linux (same machine, other OS?) TODO confirm |
| `iphone182` | 100.93.14.38 | iOS |

### Subnet routes

The Proxmox hosts advertise the same routes, so remote access survives one node being down. All three Proxmox nodes advertise the same routes (`pvenode2` checked 2026-10-27). Only the VLANs needed for remote access are advertised.

| Route | VLAN | Advertised (all Proxmox nodes) | Why |
|---|---|---|---|
| `192.168.10.0/24` | 10 MGMT | Yes | Technitium DNS for split DNS on `home.capilabs.dev` |
| `192.168.30.0/24` | 30 K8S | Yes | MetalLB IPs (Headlamp, ingress) and the API server |
| `192.168.40.0/24` | 40 APPS | Yes | Traefik for `*.home.capilabs.dev` Docker apps |
| `192.168.1.0/24` | 1 DEFAULT | No | Proxmox UIs reachable on their Tailscale IPs instead |
| `192.168.20.0/24` | 20 NAS | No | NAS kept off the tailnet |

Routes must also be **approved** per node in the admin console.

Advertised routes were confirmed with `tailscale debug prefs | grep -A8 AdvertiseRoutes` on `pvemaster1` and `pvenode2`. TODO: tick approval for all three nodes in the admin console (`pvenode1` not re-checked since the swap).
