# Kubernetes

## Cluster

| Node | IP (VLAN 30) |
|---|---|
| `k8s-master1` | 192.168.30.10 |
| `k8s-worker1` | 192.168.30.11 |
| `k8s-worker2` | 192.168.30.12 |

- Ubuntu 24.04, Kubernetes v1.36.4, containerd, Flannel CNI.
- Pod CIDR `10.244.0.0/16`.
- API server: `192.168.30.10:6443` — confirmed via the `kubernetes` service endpoint (2026-10-06).
- Equivalent init flags:
  ```bash
  kubeadm init --apiserver-advertise-address=192.168.30.10 --pod-network-cidr=10.244.0.0/16
  ```
- Service CIDR: the `kubernetes` service sits at `10.96.0.1`, i.e. kubeadm's default `10.96.0.0/12`.

### API server certificate

SANs on `/etc/kubernetes/pki/apiserver.crt` (checked 2026-10-06):

| Type | Values |
|---|---|
| DNS | `k8s-master1`, `kubernetes`, `kubernetes.default`, `kubernetes.default.svc`, `kubernetes.default.svc.cluster.local` |
| IP | `10.96.0.1` (service IP), `192.168.30.10` |

The cert covers only the VLAN 30 address — nothing from the old 192.168.1.x network — so it was issued for the cluster as it runs today.

Since `192.168.30.10` is in the SANs, `kubectl` works over Tailscale through the VLAN 30 subnet route with no changes. To reach the API by a DNS name (e.g. `k8s.home.capilabs.dev`), that name must be added as a SAN first:

```bash
# on k8s-master1 — back up first
sudo mv /etc/kubernetes/pki/apiserver.{crt,key} /root/
sudo kubeadm init phase certs apiserver \
  --apiserver-advertise-address=192.168.30.10 \
  --apiserver-cert-extra-sans=k8s.home.capilabs.dev
# then restart the API server: move its manifest out of and back into /etc/kubernetes/manifests
```

Check expiry with `sudo kubeadm certs check-expiration` — kubeadm certs last one year and are renewed automatically on control-plane upgrades.
