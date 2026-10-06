# Hardware inventory

## Compute

| Host | Model | CPU | RAM | NICs | Switch port | Role |
|---|---|---|---|---|---|---|
| `pvenode1` | Dell OptiPlex Micro 7010 | i5-13500T | 32 GB DDR4-3200 | onboard 1G (`nic0`, idle fallback) + UGREEN USB 2.5G, RTL8156 (`enx6c1ff7cd73a6`, active on `vmbr1`) | `ether4` (USB adapter) · TODO: onboard port | Proxmox node |
| `master1` | HP Pro Mini 400 G9 | i5-13500T | 32 GB DDR4-3200 | onboard 1G (`nic0`, idle fallback) + UGREEN USB 2.5G, RTL8156 (`enx6c1ff7cd71c6`, USB path `2-9`, active on `vmbr1`) | `ether1` (onboard) · TODO: USB adapter port | Proxmox node |
| Third node | TODO: model (candidates: HP Elite Mini 800 G9 i7-12700T, EliteDesk 800 G6 i7-10700T, EliteDesk 800 G3) | TODO | TODO | TODO | TODO (`ether4` was planned, but pvenode1's USB adapter is on `ether4` — verify) | Proxmox node (incoming) |
| QDevice | AWS EC2 | — | — | Tailscale `100.109.27.36` | — | Cluster quorum (`corosync-qnetd`) |

**NIC upgrade path:** `master1` can take an HP Flex IO V2 2.5GbE module (Intel i225-V) to replace the USB adapter. `pvenode1` has no NIC expansion option, so it stays on USB.

**Measured:** iperf3 `pvenode1` ↔ `master1` over the USB adapters holds ~2.35 Gbit/s sustained.

**Long term:** replace the mini PCs with real servers (still evaluating).

## Storage

| Device | Details |
|---|---|
| UGREEN DXP2800 (NAS) | UGOS Pro. 2× 4 TB CMR HDD, RAID 1. WD Red SN700 NVMe installed, **not configured as cache**. 256 GB M.2 holds TrueNAS SCALE (dual-boot, not used — see [ADR-0003](../decisions/0003-ugos-over-truenas.md)); candidate to wipe and reuse as read-only SSD cache. NFS shared storage for the cluster. |

## Network

| Device | Details |
|---|---|
| MikroTik CRS310-8G+2S+IN | Core switch/router, VLANs + inter-VLAN routing. Replaced a defective TRENDnet TEG-3102WS. |
| Cabling | Cat5e — confirmed sufficient for 2.5G |
| Workstation | Realtek 2.5GbE NIC |

## Power

| Device | Details |
|---|---|
| Forza BT-601 UPS | 600 VA, manual shutdown. Est. ~15–25 min at 60–120 W load. TODO: automated shutdown (NUT?) |
| Tapo smart plugs | Per-device power monitoring → Home Assistant |

Utility: Air-e, ~900 COP/kWh. Full stack estimated at ~60 kWh/month.

## Peripherals

- HDMI switch has EDID issues with the OptiPlex Proxmox console. Fix options: TESmart switch with per-port EDID emulation, or an inline EDID emulator dongle.

## Switch port map

TODO: fill in completely.

| Port | Device | Mode / VLANs |
|---|---|---|
| ether1 | `master1` onboard `nic0` (idle fallback) | TODO |
| ether2 | TODO | |
| ether3 | TODO | |
| ether4 | `pvenode1` USB 2.5G | trunk 1 + 10/20/30/40 — TODO verify tagging |
| ether5–8 | TODO | |
| sfp+1–2 | TODO | |
