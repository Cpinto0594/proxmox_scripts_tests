# Proxmox cluster

## Nodes

| Node | IP | Notes |
|---|---|---|
| `pvemaster1` | 192.168.1.90 | HP Pro Mini 400 G9 |
| `pvenode1` | 192.168.1.91 | Dell OptiPlex Micro 7010 |
| Third node | 192.168.1.92 (planned) | Incoming — will host the 3rd Patroni/Galera VM |

TODO: Proxmox VE version, cluster name.

## Quorum

Two nodes can't keep quorum alone, so an external **QDevice** runs on AWS EC2:

- `corosync-qnetd` on EC2, reachable at Tailscale IP `100.109.27.36`.
- Tailscale runs on the Proxmox host OS (not in a VM) so `corosync-qdevice` can route to it.
- EventBridge + SNS alert on EC2 instance state changes.

Once the third node joins, re-evaluate whether the QDevice is still needed (3 votes without it). TODO.

## Networking

- `vmbr1` = VLAN-aware bridge on the USB 2.5G adapter, trunking 10/20/30/40; carries the management IP/gateway and per-VLAN host IPs.
- `vmbr0` = onboard 1G `nic0`, kept configured with no IP as a fallback.
- Migration to `vmbr1` was staged on `pvemaster1` first, then repeated on `pvenode1`.
- Full write-up, both nodes' `/etc/network/interfaces`, and failback steps: [2.5G USB adapters](../network/usb-2.5g-adapters.md).

## Storage

| Storage | Type | Use |
|---|---|---|
| NAS (DXP2800) | NFS over VLAN 20 | Shared cluster storage, ISOs/backups — TODO list storage IDs |
| `Mem256` | NFS | TODO: purpose |
| Local | LVM-thin | OS installs (preferred) |
| Local ZFS | `zpool create -o ashift=12` on dedicated VM drive, separate ISO dataset | Transitional, used before the NAS came online — TODO: still in use? |

## Access & hardening

- SSH: `PasswordAuthentication no`, `PermitRootLogin prohibit-password` on all nodes.
- Ansible is the intended way to apply this consistently — TODO: link playbook repo.

## VMs and LXCs

Source: `pvesh get /cluster/resources --type vm` plus each guest's config (captured 2026-10-06). All guests attach to `vmbr1`. IPs are set inside the guests, not via cloud-init, so they come from the [IP plan](../inventory/ip-plan.md).

### Running

| ID | Proxmox name | Hostname | Type | Node | vCPU | RAM | Disk | VLAN | IP | Onboot |
|---|---|---|---|---|---|---|---|---|---|---|
| 100 | `k8s-master1` | `k8s-master1` | VM | `pvemaster1` | 2 | 8 GB | 50 GB | 30 | 192.168.30.10 | yes |
| 102 | `k8s-worker1` | `k8s-worker1` | VM | `pvenode1` | 4 | 6 GB | 50 GB | 30 | 192.168.30.11 | yes |
| 103 | `k8s-worker2` | `k8s-worker2` | VM | `pvenode1` | 4 | 6 GB | 50 GB | 30 | 192.168.30.12 | yes |
| 104 | `docker` | `docker-dev-1` | VM | `pvemaster1` | 6 | 12 GB | 150 GB | 40 | 192.168.40.10 | yes |
| 107 | `docker.worker.1` | `docker-worker-1` | VM | `pvenode1` | 6 | 8 GB | 100 GB | 40 | 192.168.40.11 | yes |
| 108 | `technitium-dns` | — | LXC | `pvemaster1` | 1 | 0.5 GB | 10 GB | 10 | 192.168.10.2 | yes |

### Stopped (lab)

| ID | Proxmox name | Node | vCPU | RAM | Disk | VLAN | IP | Notes |
|---|---|---|---|---|---|---|---|---|
| 101 | `pg.patroni.vm1` | `pvemaster1` | 2 | 4 GB | 50 GB | 40 | TODO | Patroni + etcd lab |
| 105 | `pg.patroni.vm2` | `pvemaster1` | 2 | 4 GB | 50 GB | 40 | TODO | Patroni + etcd lab |
| 106 | `pg.patroni.vm3` | `pvenode1` | 2 | 4 GB | 50 GB | 40 | TODO | Patroni + etcd lab — moves to the third node when it arrives |

### Templates

| ID | Name | Node | Notes |
|---|---|---|---|
| 109 | `docker-template-ubuntu-server-24.04.4` | `pvemaster1` | Ubuntu 24.04.4 with Docker, for new Swarm nodes. Untagged NIC — set the VLAN tag after cloning |
| 900 | `ubuntu-24.04.4-server-template` | `pvemaster1` | Base Ubuntu 24.04.4. Untagged NIC — set the VLAN tag after cloning |

Both templates live only on `pvemaster1`'s storage. TODO: confirm both are marked as templates (`template: 1` in the config) and check whether they're on shared storage — if not, clones to `pvenode1` need a full copy.

### Planned (not created yet)

| Name | VLAN | Notes |
|---|---|---|
| Galera ×3 + MaxScale | 40 | MariaDB HA lab |
| Pterodactyl Wings node | TODO | Dedicated node, plain Docker Compose |

## Capacity and placement

Both hosts have 32 GB RAM and an i5-13500T (14 cores / 20 threads).

| Node | Running guests | vCPU allocated | RAM allocated |
|---|---|---|---|
| `pvemaster1` | k8s-master1, docker-dev-1, technitium-dns | 9 | 20.5 GB |
| `pvenode1` | k8s-worker1, k8s-worker2, docker-worker-1 | 14 | 20 GB |
| **Total** | | 23 | 40.5 GB |

Findings:

- **No room for a node failure.** Running guests need 40.5 GB, more than one 32 GB host. If either node goes down, its guests can't all be restarted on the other — plan on that node's services being down until it's back (or until the third node arrives).
- **Starting the Patroni lab is tight on `pvemaster1`.** VMs 101 and 105 add 8 GB there → 28.5 GB of 32 GB. Consider moving 105 to `pvenode1` for now (28 GB there instead) or trimming them to 2 GB each for a learning lab.
- **Patroni quorum lives on one host.** Two of three etcd members (101, 105) are on `pvemaster1`; losing that host loses etcd quorum. Fine for a lab, and resolved once VM 106 moves to the third node and 101/105 are split.
- **Kubernetes workloads live on one host.** Both workers are on `pvenode1`; if it goes down, the cluster has a control plane but nowhere to run pods.
- **Control plane is larger than the workers.** `k8s-master1` has 8 GB while the workers have 6 GB. A control plane this size usually runs comfortably in 4 GB; moving 2–4 GB to the workers would better match where the load is.
- **Proxmox names differ from hostnames** for the Docker VMs (`docker` → `docker-dev-1`, `docker.worker.1` → `docker-worker-1`). Renaming in Proxmox (VM → Options → Name) would make the UI, Beszel, and these docs line up.
