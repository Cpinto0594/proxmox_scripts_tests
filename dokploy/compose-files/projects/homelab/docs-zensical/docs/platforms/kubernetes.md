# Kubernetes

## Cluster

| Node | IP (VLAN 30) |
|---|---|
| `k8s-master1` | 192.168.30.10 |
| `k8s-worker1` | 192.168.30.11 |
| `k8s-worker2` | 192.168.30.12 |

- Ubuntu 24.04, Kubernetes v1.36.4, containerd, Flannel CNI.
- Pod CIDR `10.244.0.0/16`.
- Originally built on 192.168.1.x; initial init was:
  ```bash
  kubeadm init --apiserver-advertise-address=192.168.1.100 --pod-network-cidr=10.244.0.0/16
  ```
  TODO: document how the API server cert / advertise address was updated for the move to VLAN 30.

## Managed from the workstation

Cluster add-ons are managed with **Terragrunt/Terraform from the local machine**, not from the nodes.

| Component | Notes |
|---|---|
| MetalLB | Pool 192.168.1.240–250 (TODO: verify after VLAN 30 move) |
| ingress-nginx | |
| Headlamp | Kubernetes UI |

TODO: link the Terragrunt repo.

## Bootstrap lessons

| Symptom | Cause | Fix |
|---|---|---|
| kubelet failing | Swap enabled | Disable swap (and remove from fstab) |
| Flannel CrashLoopBackOff | `br_netfilter` missing on workers | `modprobe br_netfilter` + persist in `/etc/modules-load.d/` |
| Pod networking broken | Pod CIDR overlapped the LAN subnet | Use `10.244.0.0/16` |
