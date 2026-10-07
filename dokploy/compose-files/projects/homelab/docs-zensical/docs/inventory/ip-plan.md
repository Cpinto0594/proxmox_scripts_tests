# IP plan

## VLANs

| VLAN | Subnet | Purpose | Gateway |
|---|---|---|---|
| 1 | 192.168.1.0/24 | DEFAULT — main LAN, Proxmox host IPs, home router uplink | 192.168.1.1 |
| 10 | 192.168.10.0/24 | MGMT — infra services (DNS) | TODO |
| 20 | 192.168.20.0/24 | NAS — storage | TODO |
| 30 | 192.168.30.0/24 | K8S — Kubernetes | TODO |
| 40 | 192.168.40.0/24 | APPS — Docker / Dokploy, DB clusters | TODO |

Inter-VLAN routing is on the MikroTik (confirmed working at least between VLAN 1 and VLAN 10).

## Static assignments

### Proxmox hosts

All host IPs live on `vmbr1` (USB 2.5G adapter) and its VLAN sub-interfaces. `vmbr0` (onboard 1G) and `vmbr0.10/.20/.30/.40` exist as a fallback but are down with no IPs.

| Host | VLAN 1 (`vmbr1`) | VLAN 10 (`vmbr1.10`) | VLAN 20 (`vmbr1.20`) | VLAN 30 (`vmbr1.30`) | VLAN 40 (`vmbr1.40`) | Switch port |
|---|---|---|---|---|---|---|
| `pvemaster1` | 192.168.1.90 | 192.168.10.5 | 192.168.20.5 | 192.168.30.5 | 192.168.40.5 | ether2 |
| `pvenode1` | 192.168.1.91 | 192.168.10.6 | 192.168.20.6 | 192.168.30.6 | 192.168.40.6 | ether3 |
| Third node (planned, not arrived) | 192.168.1.92 | 192.168.10.7 | 192.168.20.7 | 192.168.30.7 | 192.168.40.7 | ether4 |

All subnets are /24. Pattern: each new node takes the previous node's addresses +1 — `.90`, `.91`, `.92` on VLAN 1 and `.5`, `.6`, `.7` on VLANs 10–40. The third node's IPs are reserved; don't assign them elsewhere.

### Infrastructure

| Name | IP | Notes |
|---|---|---|
| Technitium DNS | 192.168.10.2 | LXC 108 on `pvemaster1` |
| DXP2800 (UGOS) | 192.168.20.2 | NFS |

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
| `pg.patroni.vm1/2/3` (VMs 101, 105, 106) | TODO | Created, stopped |
| Galera VMs + MaxScale | TODO | Planned |

## Tailscale

### Infrastructure nodes

| Node | Tailscale IP | Why it's on the tailnet |
|---|---|---|
| `pvemaster1` | 100.64.117.20 | corosync-qdevice → EC2 QDevice |
| `pvenode1` | 100.68.240.6 | corosync-qdevice → EC2 QDevice |
| `docker-dev-1` | 100.64.122.124 | Swarm manager / Dokploy admin access |
| `docker-worker-1` | 100.69.115.109 | Swarm worker admin access |
| `ec2-qdevice` | 100.109.27.36 | Cluster quorum (`corosync-qnetd`) — direct connection, not relayed |

### Client devices

| Device | Tailscale IP | OS |
|---|---|---|
| `desktop-ep0ql4s` | 100.115.59.61 | Windows |
| `desktop-ep0ql4s-1` | 100.85.105.66 | Linux (same machine, other OS?) TODO confirm |
| `iphone182` | 100.93.14.38 | iOS |

### Subnet routes

Both Proxmox hosts advertise the same routes, so remote access survives one node being down. Only the VLANs needed for remote access are advertised.

| Route | VLAN | Advertised (both nodes) | Why |
|---|---|---|---|
| `192.168.10.0/24` | 10 MGMT | Yes | Technitium DNS for split DNS on `home.capilabs.dev` |
| `192.168.30.0/24` | 30 K8S | Yes | MetalLB IPs (Headlamp, ingress) and the API server |
| `192.168.40.0/24` | 40 APPS | Yes | Traefik for `*.home.capilabs.dev` Docker apps |
| `192.168.1.0/24` | 1 DEFAULT | No | Proxmox UIs reachable on their Tailscale IPs instead |
| `192.168.20.0/24` | 20 NAS | No | NAS kept off the tailnet |

Routes must also be **approved** per node in the admin console.

TODO: confirm with `tailscale debug prefs | grep -A8 AdvertiseRoutes` on both nodes and tick approval in the admin console.
