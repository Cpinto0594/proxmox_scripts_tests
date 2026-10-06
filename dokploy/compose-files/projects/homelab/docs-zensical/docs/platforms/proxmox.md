# Proxmox cluster

## Nodes

| Node | IP | Notes |
|---|---|---|
| `master1` | 192.168.1.90 | HP Pro Mini 400 G9 |
| `pvenode1` | 192.168.1.91 | Dell OptiPlex Micro 7010 |
| Third node | TODO | Incoming — will host the 3rd Patroni/Galera VM |

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
- Migration to `vmbr1` was staged on `master1` first, then repeated on `pvenode1`.
- TODO: commit each node's `/etc/network/interfaces`.

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

TODO: generate with `pvesh get /cluster/resources --type vm --output-format yaml` and summarize here.

| ID | Name | Node | VLAN | Purpose |
|---|---|---|---|---|
| TODO | `docker-dev-1` | TODO | 40 | Swarm manager / Dokploy — 150 GB disk, LVM `ubuntu-vg/ubuntu-lv` |
| TODO | `docker-worker-1` | TODO | 40 | Swarm worker |
| TODO | `k8s-master1`, `k8s-worker1/2` | TODO | 30 | Kubernetes |
| TODO | Patroni ×3 | TODO | 40 | Postgres HA lab |
| TODO | Galera ×3 | TODO | 40 | MariaDB HA lab |
| TODO | Technitium LXC | TODO | 10 | DNS |
