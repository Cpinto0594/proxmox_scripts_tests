# Proxmox cluster

## Nodes

| Node | IP | Notes |
|---|---|---|
| `pvemaster1` | 192.168.1.90 | HP Elite Mini 800 G9, i7-12700T, **16 GB RAM** (new hardware), running the cloned disk of the old `pvemaster1` |
| `pvenode1` | 192.168.1.91 | Dell OptiPlex Micro 7010 |
| `pvenode2` | 192.168.1.92 | HP Pro Mini 400 G9, i5-13500T, 32 GB (the former `pvemaster1`). Third node, in the cluster. Will host the 3rd Patroni/Galera VM. Uses `vmbr1` like the other nodes (see Networking) |

!!! note "Hardware swap (2026-10-27)"
    The third node arrived as new hardware. The old `pvemaster1` disk was cloned onto it, so the new machine is `pvemaster1` and its guests came with it. The old HP Pro Mini was renamed `pvenode2` and became the third node. See [gotchas](../gotchas.md#proxmox-storage-network).

Cluster name: `Cluster`, 3 nodes (checked with `pvecm status`, 2026-10-27). All three nodes run Proxmox VE `pve-manager/9.2.18` (kernel `7.0.14-16-pve`, EFI with Secure Boot, as shown on `pvemaster1`; same version confirmed on all nodes 2026-10-27).

## Quorum

Three nodes, **3 expected votes**, quorum is 2 (`pvecm status`, 2026-10-27). One node can be down and the cluster stays quorate.

## Networking

- `vmbr1` = VLAN-aware bridge on the USB 2.5G adapter, trunking 10/20/30/40; carries the management IP/gateway and per-VLAN host IPs.
- `vmbr0` = onboard 1G, kept configured with no IP as a fallback.
- Full write-up, both nodes' `/etc/network/interfaces`, and failback steps: [2.5G USB adapters](../network/usb-2.5g-adapters.md).

## Storage

Source: `pvesm status` and `/etc/pve/storage.cfg` on `pvemaster1` (2026-10-27). The NAS is `192.168.20.2` (VLAN 20).

| Storage ID | Type | Available on | Content | Size (used) |
|---|---|---|---|---|
| `images_nas` | NFS, `/volume1/proxmox_images` | all nodes (shared) | VM and CT disks | 200 GiB (0) |
| `backups_nas` | NFS, `/volume1/proxmox_backups` | all nodes (shared) | ISOs, CT templates, backups, snippets | 300 GiB (199.6 GiB, 67%). `keep-all` backup retention |
| `local` | Directory, `/var/lib/vz` | each node, **local** | backups, CT templates, imports, ISOs | 93 GiB per node (5–7 GiB) |
| `local-lvm` | LVM-thin | each node, **local** | VM and CT disks | `pvemaster1` 348 GiB (73.6), `pvenode1` 347 GiB (83.8), `pvenode2` 348 GiB (10.2) |
| `lvm_thinpool_ssd480_node1` | LVM-thin | `pvenode1` only | VM and CT disks | 438 GiB (0) |
| `lvm_thinpool_ssd512_node2` | LVM-thin | `pvenode2` only | VM and CT disks | 462 GiB (0) |

`images_nas` and both per-node SSD pools show 0 GiB used, so all guest disks are on each node's `local-lvm`. Because `local-lvm` is node-local, moving a guest to another node copies its disk (`--with-local-disks`).

## Access & hardening

- SSH: `PasswordAuthentication no`, `PermitRootLogin prohibit-password` on all nodes.
- Ansible is the intended way to apply this consistently — TODO: link playbook repo.

## VMs and LXCs

Source: `pvesh get /cluster/resources --type vm` plus each guest's config. vCPU and RAM were refreshed from the cluster on 2026-10-27; disk sizes are from 2026-10-06. All guests attach to `vmbr1`. IPs are set inside the guests, not via cloud-init, so they come from the [IP plan](../inventory/ip-plan.md).

### Running

| ID | Proxmox name | Hostname | Type | Node | vCPU | RAM | Disk | VLAN | IP | Onboot |
|---|---|---|---|---|---|---|---|---|---|---|
| 100 | `k8s-master1` | `k8s-master1` | VM | `pvemaster1` | 2 | 4 GB | 50 GB | 30 | 192.168.30.10 | yes |
| 102 | `k8s-worker1` | `k8s-worker1` | VM | `pvenode1` | 4 | 6 GB | 50 GB | 30 | 192.168.30.11 | yes |
| 103 | `k8s-worker2` | `k8s-worker2` | VM | `pvenode2` | 4 | 6 GB | 50 GB | 30 | 192.168.30.12 | yes |
| 104 | `docker.dev.1` | `docker-dev-1` | VM | `pvemaster1` | 6 | 8 GB | 150 GB | 40 | 192.168.40.10 | yes |
| 107 | `docker.worker.1` | `docker-worker-1` | VM | `pvenode1` | 6 | 6 GB | 100 GB | 40 | 192.168.40.11 | yes |
| 108 | `technitium-dns` | — | LXC | `pvemaster1` | 1 | 0.5 GB | 10 GB | 10 | 192.168.10.2 | yes |

### Stopped

| ID | Proxmox name | Node | vCPU | RAM | Disk | VLAN | IP | Notes |
|---|---|---|---|---|---|---|---|---|
| 110 | `wings-gameserver-01` | `pvenode1` | 2 | 4 GB | TODO | TODO | TODO | Pterodactyl Wings node |

### Templates

| ID | Name | Node | Notes |
|---|---|---|---|
| 901 | `docker-template-ubuntu-server-24.04.04` | `pvemaster1` | Ubuntu 24.04.4 with Docker, for new Swarm nodes. Untagged NIC — set the VLAN tag after cloning |
| 900 | `ubuntu-24.04.4-server-template` | `pvemaster1` | Base Ubuntu 24.04.4. Untagged NIC — set the VLAN tag after cloning |

Both are marked as templates and their disks are on `local-lvm` on `pvemaster1`, which is **not shared**. A clone can't target another node directly; clone on `pvemaster1` with `--full`, then `qm migrate <newid> <node> --with-local-disks`, or move a template's disk to `images_nas` so any node can clone it.

### Planned (not created yet)

| Name | VLAN | Notes |
|---|---|---|
| Galera ×3 + MaxScale | 40 | MariaDB HA lab |

## Capacity and placement

Source: `pvesh get /cluster/resources` (2026-10-27). `pvenode1` and `pvenode2` have 32 GB RAM (31 GB usable) and an i5-13500T (14 cores / 20 threads). `pvemaster1` has an i7-12700T (12 cores / 20 threads) but only **16 GB** RAM (15 GB usable).

| Node | Running guests | vCPU allocated | RAM allocated | RAM in use |
|---|---|---|---|---|
| `pvemaster1` (15 GB usable) | k8s-master1, docker-dev-1, technitium-dns | 9 | 12.5 GB | 10.4 GB |
| `pvenode1` (31 GB usable) | k8s-worker1, docker-worker-1 | 10 | 12 GB | 9.7 GB |
| `pvenode2` (31 GB usable) | k8s-worker2 | 4 | 6 GB | 3.9 GB |
| **Total** | | 23 | 30.5 GB of 77 GB | 24 GB |

VM 110 (`wings-gameserver-01`, 2 vCPU / 4 GB) is stopped on `pvenode1`; starting it takes that node to 16 GB allocated.

Findings:

- **`pvemaster1` is the tight node.** 10.4 of 15 GB are in use, with 12.5 GB allocated. It is no longer over-allocated, but only about 4.5 GB is free. A second memory module is planned.
- **Node failure is survivable.** `pvenode2` has about 27 GB free, enough to take all of `pvemaster1`'s or `pvenode1`'s guests. `pvemaster1` can't absorb another node's guests: only 2.5 GB are unallocated.
- **Kubernetes workers are split across hosts.** `k8s-worker1` is on `pvenode1` and `k8s-worker2` on `pvenode2`, so losing one worker host leaves the other worker running. The control plane (`k8s-master1`, 4 GB) is on `pvemaster1`, a single host.
- **Proxmox names differ from hostnames** for the Docker VMs (`docker.dev.1` → `docker-dev-1`, `docker.worker.1` → `docker-worker-1`). Renaming in Proxmox (VM → Options → Name) would make the UI, Beszel, and these docs line up.
