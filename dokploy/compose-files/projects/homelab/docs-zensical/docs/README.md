# capilabs homelab

Documentation for the homelab: Proxmox cluster, Kubernetes, Dokploy/Docker Swarm, NAS, and networking.

> **Rule:** no secrets in this repo. Reference the Infisical path instead (e.g. `infisical:/homelab/forgejo/db-password`).
> **Rule:** a change isn't done until the relevant page here is updated.

## Topology

```mermaid
flowchart TB
    internet((Internet)) --> cf[Cloudflare<br/>Tunnel + DNS]
    ts((Tailscale<br/>tailnet)) -.-> pve1 & pve2 & dd1 & dw1

    subgraph lan[MikroTik CRS310-8G+2S+IN · inter-VLAN routing]
        direction TB
        subgraph v1[VLAN 1 · 192.168.1.0/24 · mgmt]
            pve1[pvenode1<br/>OptiPlex Micro 7010<br/>.1.91]
            pve2[pvemaster1<br/>HP Elite Mini 800 G9<br/>.1.90]
            pve3[pvenode2<br/>HP Pro Mini 400 G9<br/>.1.92]
        end
        subgraph v10[VLAN 10 · 192.168.10.0/24]
            dns[Technitium DNS<br/>.10.2]
        end
        subgraph v20[VLAN 20 · 192.168.20.0/24 · storage]
            nas[UGREEN DXP2800<br/>.20.2 · NFS]
        end
        subgraph v30[VLAN 30 · 192.168.30.0/24 · k8s]
            k8s[k8s-master1 .30.10<br/>k8s-worker1 .30.11<br/>k8s-worker2 .30.12]
        end
        subgraph v40[VLAN 40 · 192.168.40.0/24 · APPS]
            dd1[docker-dev-1<br/>Swarm manager · Dokploy<br/>.40.10]
            dw1[docker-worker-1<br/>Swarm worker<br/>.40.11]
        end
    end

    cf --> cloudflared[cloudflared] --> traefik[dokploy-traefik:80]
    traefik --> dd1 & dw1
    pve1 & pve2 & pve3 -.NFS.-> nas
```

## Map of this repo

| Path | What's there |
|---|---|
| [inventory/hardware.md](inventory/hardware.md) | Physical devices, specs, switch ports |
| [inventory/ip-plan.md](inventory/ip-plan.md) | VLANs and every static IP |
| [network/](network/README.md) | MikroTik, VLANs, Tailscale, Cloudflare Tunnel, DNS |
| [platforms/proxmox.md](platforms/proxmox.md) | Cluster, quorum, storage, NICs |
| [platforms/kubernetes.md](platforms/kubernetes.md) | kubeadm cluster, MetalLB, ingress, Headlamp |
| [platforms/dokploy-swarm.md](platforms/dokploy-swarm.md) | Swarm nodes + **compose conventions** |
| [services/](services/README.md) | Service catalog |
| [gotchas.md](gotchas.md) | Hard-won lessons — read before debugging |
| [open-items.md](open-items.md) | Unresolved problems and planned work |
| [worklog.md](worklog.md) | Chronological log of work done, newest first |

## Conventions for this repo

- `TODO:` marks a fact that still needs to be filled in or verified. `grep -rn TODO .` to find them.
- Diagrams in Mermaid (Forgejo renders them).
- Keep compose files / Terragrunt in their own repos and **link** to them; don't paste copies that drift.
- Mirror this repo outside the lab (private GitHub or a local clone) so it's readable when the lab is down.
