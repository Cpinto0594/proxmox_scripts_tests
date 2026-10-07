# Hardware inventory

## Compute

| Host | Model | CPU | RAM | NICs | Switch port | Role |
|---|---|---|---|---|---|---|
| `pvenode1` | Dell OptiPlex Micro 7010 | i5-13500T | 32 GB DDR4-3200 | onboard 1G (`nic0`, idle fallback) + UGREEN USB 2.5G, RTL8156 (`enx6c1ff7cd73a6`, active on `vmbr1`) | `ether3` | Proxmox node |
| `pvemaster1` | HP Pro Mini 400 G9 | i5-13500T | 32 GB DDR4-3200 | onboard 1G (`nic0`, idle fallback) + UGREEN USB 2.5G, RTL8156 (`enx6c1ff7cd71c6`, USB path `2-9`, active on `vmbr1`) | `ether2` | Proxmox node |
| Third node | TODO: model (candidates: HP Elite Mini 800 G9 i7-12700T, EliteDesk 800 G6 i7-10700T, EliteDesk 800 G3) | TODO | TODO | TODO | `ether4` (reserved) | Proxmox node (not arrived yet) |
| QDevice | AWS EC2 | — | — | Tailscale `100.109.27.36` | — | Cluster quorum (`corosync-qnetd`) |

**NIC upgrade path:** `pvemaster1` can take an HP Flex IO V2 2.5GbE module (Intel i225-V) to replace the USB adapter. `pvenode1` has no NIC expansion option, so it stays on USB.

**Measured:** iperf3 `pvenode1` ↔ `pvemaster1` over the USB adapters holds ~2.35 Gbit/s sustained. Details: [2.5G USB adapters](../network/usb-2.5g-adapters.md).

**Long term:** replace the mini PCs with real servers (still evaluating).

## Storage

| Device | Details |
|---|---|
| UGREEN DXP2800 (NAS) | UGOS Pro. 2× 4 TB CMR HDD, RAID 1. WD Red SN700 NVMe installed, **not configured as cache**. Spare 256 GB M.2 SSD is a candidate for a read-only SSD cache. NFS shared storage for the cluster. |

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

MikroTik CRS310-8G+2S+IN, single bridge `bridge`, all ports hardware-offloaded.
Source: `/interface bridge port print` and `/interface bridge vlan print`.

| Port | Device | PVID | Untagged | Tagged | Link |
|---|---|---|---|---|---|
| ether1 | Uplink to home router | 1 | 1 | — | Up |
| ether2 | `pvemaster1` (HP Pro Mini), trunk | 1 | 1 | 10, 20, 30, 40 | Up |
| ether3 | `pvenode1` (Dell OptiPlex), trunk | 1 | 1 | 10, 20, 30, 40 | Up |
| ether4 | Reserved: third Proxmox node | 1 | — | — | Down (no device) |
| ether5 | UGREEN DXP2800 NAS, access | 20 | 20 | — | Up |
| ether6–8 | Unused (defconf) | 1 | — | — | Down |
| sfp-sfpplus1–2 | Unused (defconf) | 1 | — | — | Down |

The bridge itself is tagged on VLANs 10, 20, 30, and 40, so the switch has an L3 interface on each.

When the third node arrives, add `ether4` to the VLAN table the same way as `ether2`/`ether3`:

```
/interface bridge vlan set [find vlan-ids=1]  untagged=bridge,ether1,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=10] tagged=bridge,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=20] tagged=bridge,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=30] tagged=bridge,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=40] tagged=bridge,ether2,ether3,ether4
```
