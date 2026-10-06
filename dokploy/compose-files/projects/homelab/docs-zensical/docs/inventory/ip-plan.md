# IP plan

## VLANs

| VLAN | Subnet | Purpose | Gateway |
|---|---|---|---|
| 1 | 192.168.1.0/24 | Main / management (Proxmox hosts) | TODO (MikroTik) |
| 10 | 192.168.10.0/24 | Infra services (DNS) | TODO |
| 20 | 192.168.20.0/24 | Storage | TODO |
| 30 | 192.168.30.0/24 | Kubernetes | TODO |
| 40 | 192.168.40.0/24 | APPS (Docker / Dokploy, DB clusters) | TODO |

Inter-VLAN routing is on the MikroTik (confirmed working at least between VLAN 1 and VLAN 10).

## Static assignments

### Proxmox hosts

| Host | VLAN 1 | VLAN 10 | VLAN 20 | VLAN 30 | VLAN 40 | Bridge |
|---|---|---|---|---|---|---|
| `master1` | 192.168.1.90 | TODO | TODO | TODO | TODO | `vmbr1` (USB) |
| `pvenode1` | 192.168.1.91 | 192.168.10.6 | 192.168.20.6 | 192.168.30.6 | 192.168.40.6 | `vmbr1` (USB) |

### Infrastructure

| Name | IP | Notes |
|---|---|---|
| Technitium DNS | 192.168.10.2 | Moving to a dedicated LXC |
| DXP2800 (UGOS) | 192.168.20.2 | NFS |
| DXP2800 (TrueNAS boot) | 192.168.20.200 | Only when booted into TrueNAS |

### Kubernetes (VLAN 30)

| Name | IP |
|---|---|
| `k8s-master1` | 192.168.30.10 |
| `k8s-worker1` | 192.168.30.11 |
| `k8s-worker2` | 192.168.30.12 |
| MetalLB pool | 192.168.1.240–192.168.1.250 — TODO verify: still on VLAN 1 after the nodes moved to VLAN 30? |

### Docker / Apps (VLAN 40)

| Name | IP | Notes |
|---|---|---|
| `docker-dev-1` | 192.168.40.10 | Swarm manager, Dokploy. Formerly 192.168.10.10 |
| `docker-worker-1` | 192.168.40.11 | Swarm worker |
| Patroni / etcd VMs | TODO | Planned |
| Galera VMs + MaxScale | TODO | Planned |

## Published host ports

| Host | Port | Service |
|---|---|---|
| `docker-dev-1` | 9003 | Infisical backend |
| `docker-dev-1` | 2222 | Forgejo SSH |
| `docker-worker-1` | 9004 | Home Assistant |

## Tailscale

| Node | Tailscale IP |
|---|---|
| QDevice (EC2) | 100.109.27.36 |
| `docker-dev-1` | 100.64.122.124 |
| `docker-worker-1` | TODO |
| `pvenode1` | TODO |
| `master1` | TODO |

Advertised subnet route: `192.168.1.0/24` (approved). TODO: which node advertises it.

## Retired addresses (don't reuse without checking)

| IP | Was |
|---|---|
| 192.168.1.100 | Old `k8s-master1` |
| 192.168.10.10 | Old `docker-dev-1` |
| 192.168.1.103 | Stale Swarm advertise address on `docker-dev-1` — see [open-items](../open-items.md) |
