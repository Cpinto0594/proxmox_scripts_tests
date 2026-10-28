# Hardware inventory

## Compute

| Host | Model | CPU | RAM | NICs | Switch port | Role |
|---|---|---|---|---|---|---|
| `pvenode1` | Dell OptiPlex Micro 7010 | i5-13500T | 32 GB DDR4-3200 | onboard 1G (`nic0`, idle fallback) + UGREEN USB 2.5G, RTL8156 (`enx6c1ff7cd73a6`, active on `vmbr1`) | `ether3` | Proxmox node |
| `pvemaster1` | HP Elite Mini 800 G9 (new hardware; runs the cloned disk of the old `pvemaster1`) | i7-12700T (12C/20T) | **16 GB DDR5-4800** (1 module) | onboard 1G Intel (`eno1`, e1000e, no link) + UGREEN USB 2.5G, RTL8156 (`enx6c1ff7cd71c6`, link 2500 Mbit/s, active on `vmbr1`) + Intel Wi-Fi (unused) | `ether2` | Proxmox node |
| `pvenode2` | HP Pro Mini 400 G9 (the former `pvemaster1`) | i5-13500T | 2× 16 GB DDR4 (31 GB usable; dmidecode reports 2667 MT/s) | onboard 1G (`nic0`, e1000e, no link, **unused**) + UGREEN USB 2.5G, RTL8156 (`nic1`, r8152, link 2500 Mbit/s, active on `vmbr1`) + Realtek Wi-Fi (unused). Its old adapter `enx6c1ff7cd71c6` is now in `pvemaster1` | `ether4` | Proxmox node |

**NIC upgrade path:** `pvenode2` (HP Pro Mini) can take an HP Flex IO V2 2.5GbE module (Intel i225-V) to replace the USB adapter. `pvenode1` has no NIC expansion option, so it stays on USB.

**RAM:** the new `pvemaster1` has only 16 GB, half of the other nodes, with 12.5 GB allocated to its guests (10.4 GB in use). See [capacity and placement](../platforms/proxmox.md#capacity-and-placement). A second memory module is planned.

**Measured:** iperf3 `pvenode1` ↔ the old `pvemaster1` (HP Pro Mini, now `pvenode2`) over the USB adapters holds ~2.35 Gbit/s sustained. Details: [2.5G USB adapters](../network/usb-2.5g-adapters.md).

**Long term:** replace the mini PCs with real servers (still evaluating).

## Storage

| Device | Details |
|---|---|
| UGREEN DXP2800 (NAS) | UGOS Pro. 2× 4 TB CMR HDD, RAID 1. WD Red SN700 NVMe installed (TODO: confirm its role). 256 GB M.2 SSD installed and in use as the SSD cache (TODO: confirm read-only or read-write). NFS shared storage for the cluster. |

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

Utility: Air-e, ~900 COP/kWh. Full stack estimated at ~60 kWh/month.

## Peripherals

- HDMI switch has EDID issues with the OptiPlex Proxmox console. Fix options: TESmart switch with per-port EDID emulation, or an inline EDID emulator dongle.

## Switch port map

MikroTik CRS310-8G+2S+IN, single bridge `bridge`, all ports hardware-offloaded.
Source: `/interface bridge port print` and `/interface bridge vlan print` (checked 2026-10-27, all three Proxmox nodes included).

| Port | Device | PVID | Untagged | Tagged | Link |
|---|---|---|---|---|---|
| ether1 | Uplink to home router | 1 | 1 | — | Up |
| ether2 | `pvemaster1` (HP Elite Mini 800 G9), trunk | 1 | 1 | 10, 20, 30, 40 | Up |
| ether3 | `pvenode1` (Dell OptiPlex), trunk | 1 | 1 | 10, 20, 30, 40 | Up |
| ether4 | `pvenode2` (HP Pro Mini), trunk | 1 | 1 | 10, 20, 30, 40 | Up |
| ether5 | UGREEN DXP2800 NAS, access | 20 | 20 | — | Up |
| ether6–8 | Unused (defconf) | 1 | — | — | Down |
| sfp-sfpplus1–2 | Unused (defconf) | 1 | — | — | Down |

The bridge itself is tagged on VLANs 10, 20, 30, and 40, so the switch has an L3 interface on each.

`pvemaster1`, `pvenode1` and `pvenode2` are on `ether2`, `ether3` and `ether4`. `ether4` is already in the VLAN table exactly like `ether2`/`ether3` (VLAN 1 untagged, VLANs 10–40 tagged). For reference, the commands that set this up:

```
/interface bridge vlan set [find vlan-ids=1]  untagged=bridge,ether1,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=10] tagged=bridge,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=20] tagged=bridge,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=30] tagged=bridge,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=40] tagged=bridge,ether2,ether3,ether4
```

The port comments on the switch match the current devices: `ether2` was relabelled `pvemaster1 (HP Elite Mini 800 G9) - trunk` on 2026-10-27, after the hardware swap.
