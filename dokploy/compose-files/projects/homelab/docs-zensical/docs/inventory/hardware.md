# Hardware inventory

## Compute

| Host | Model | CPU | RAM | Role |
|---|---|---|---|---|
| `pvemaster1` | HP Elite Mini 800 G9 | i7-12700T (12C/20T) | 32 GB DDR5-4800 (2× 16 GB, second module added 2026-11-27) | Proxmox node |
| `pvenode1` | Dell OptiPlex Micro 7010 | i5-13500T | 32 GB DDR4-3200 | Proxmox node |
| `pvenode2` | HP Pro Mini 400 G9 | i5-13500T | 2× 16 GB DDR4 (31 GB usable, dmidecode reports 2667 MT/s) | Proxmox node |

- **Hardware swap:** `pvemaster1` is new hardware running the cloned disk of the old `pvemaster1`. The old machine is now `pvenode2`. See the [hardware swap note](ip-plan.md#proxmox-hosts).
- **RAM:** all three nodes now have 32 GB. `pvemaster1` got its second 16 GB module on 2026-11-27 (it had 16 GB since the hardware swap). TODO: confirm usable RAM and speed on the host (`free -g`, `dmidecode -t memory`). See [capacity and placement](../platforms/proxmox.md#capacity-and-placement).
- **Long term:** replace the mini PCs with real servers (still evaluating).

### Network interfaces

One row per NIC. USB adapter MACs are taken from their `enx<mac>` interface names.

| Host | NIC | Interface | Chipset / driver | MAC | Switch port | Used for |
|---|---|---|---|---|---|---|
| `pvemaster1` | USB 2.5G (UGREEN) | `enx6c1ff7cd71c6` | RTL8156B / `r8152`, link 2500 Mbit/s | `6c:1f:f7:cd:71:c6` | MikroTik `ether2` | `vmbr1`: all host and guest traffic |
| `pvemaster1` | Onboard 1G (Intel) | `eno1` | `e1000e` | `7c:57:58:5d:a2:e4` | SODOLA port 1 | [Wake-on-LAN](../network/usb-2.5g-adapters.md#wake-on-lan-onboard-nics), `vmbr0` fallback, no IP |
| `pvemaster1` | Wi-Fi (Intel) | `wlp0s20f3` | — | — | — | Unused |
| `pvenode1` | USB 2.5G (UGREEN) | `enx6c1ff7cd73a6` | RTL8156B / `r8152` | `6c:1f:f7:cd:73:a6` | MikroTik `ether3` | `vmbr1`: all host and guest traffic |
| `pvenode1` | Onboard 1G | `nic0` | TODO | `20:88:10:97:b9:44` | SODOLA port 2 | [Wake-on-LAN](../network/usb-2.5g-adapters.md#wake-on-lan-onboard-nics), `vmbr0` fallback, no IP |
| `pvenode2` | USB 2.5G (UGREEN) | `enx6c1ff7cd73e3` (was `nic1` on 2026-10-27) | RTL8156B / `r8152`, link 2500 Mbit/s | `6c:1f:f7:cd:73:e3` | MikroTik `ether4` | `vmbr1`: all host and guest traffic |
| `pvenode2` | Onboard 1G | `nic0` | `e1000e` | `30:13:8b:81:e4:a8` | SODOLA port 3 | [Wake-on-LAN](../network/usb-2.5g-adapters.md#wake-on-lan-onboard-nics), `vmbr0` fallback, no IP |
| `pvenode2` | Wi-Fi (Realtek) | — | — | — | — | Unused |

- **Adapter move:** the USB adapter now in `pvemaster1` (`enx6c1ff7cd71c6`) used to be in `pvenode2`.
- **Measured:** iperf3 `pvenode1` ↔ the old `pvemaster1` (HP Pro Mini, now `pvenode2`) over the USB adapters holds ~2.35 Gbit/s sustained. Details: [2.5G USB adapters](../network/usb-2.5g-adapters.md).
- **NIC upgrade path:** `pvenode2` (HP Pro Mini) can take an HP Flex IO V2 2.5GbE module (Intel i225-V) to replace the USB adapter. `pvenode1` has no NIC expansion option, so it stays on USB.
- **More detail:** [2.5G USB adapters](../network/usb-2.5g-adapters.md), [switch port map](#switch-port-map), [SODOLA port map](#sodola-port-map).

## Storage

| Device | Details |
|---|---|
| UGREEN DXP2800 (NAS) | UGOS Pro. 2× 4 TB CMR HDD, RAID 1. WD Red SN700 NVMe installed (TODO: confirm its role). 256 GB M.2 SSD installed and in use as the SSD cache (TODO: confirm read-only or read-write). NFS shared storage for the cluster. |

## Network

| Device | Details |
|---|---|
| MikroTik CRS310-8G+2S+IN | Core switch/router, VLANs + inter-VLAN routing. Management IP `192.168.1.2` (VLAN 1). Replaced a defective TRENDnet TEG-3102WS. Admin password: TODO store in Infisical (e.g. `infisical:/homelab/network/mikrotik-admin-password`). |
| SODOLA SL902-SWTGW218AS | Managed switch, web UI at `192.168.1.3` (VLAN 1). TODO: confirm port layout (believed 8× 2.5G RJ45 + 1× 10G SFP+), its role, its VLAN config, and what's on ports 4–7. Uplink: SODOLA port 8 ↔ MikroTik `ether8`. Ports 1–3: the Proxmox hosts' onboard 1G NICs, see [SODOLA port map](#sodola-port-map). Admin password: TODO store in Infisical (e.g. `infisical:/homelab/network/sodola-admin-password`). |
| Cabling | Cat5e — confirmed sufficient for 2.5G |
| Workstation | Realtek 2.5GbE NIC |

## Remote management (KVM)

| Device | Details |
|---|---|
| GL.iNet Comet X (GL-RM4PE) | Quad-port IP KVM: 4× HDMI in + 1× HDMI out (local console passthrough), 4× USB-C device ports to the hosts (keyboard/mouse/virtual media), 7× USB-A host ports for peripherals, 4K@30 fps over browser or app. 1× 1 GbE RJ45 with 802.3af/at PoE in; USB-C 5 V/3 A as backup power. No Wi-Fi. IP `192.168.1.79` (VLAN 1), web UI at `https://kvm.home.capilabs.dev`. Admin password: TODO store in Infisical (e.g. `infisical:/homelab/network/kvm-admin-password`). |

- **Hosts on the KVM ports:** TODO: record which machine is on HDMI/USB ports 1–4 (presumably `pvemaster1`, `pvenode1`, `pvenode2`, plus one spare).
- **Network and power:** TODO: confirm which switch port it's plugged into, and how it's powered. The MikroTik CRS310 has no PoE out (`ether1` is PoE in only), so it's on USB-C, a PoE injector, or a PoE port on the SODOLA (TODO: check whether the SODOLA has PoE).
- **Address:** TODO: confirm static IP vs DHCP reservation on the home router.
- **DNS:** `kvm.home.capilabs.dev` isn't in the Traefik dynamic config (`dokploy/traefik/dynamic/`), so it's assumed to be a Technitium A record pointing straight at `192.168.1.79`, with the KVM serving its own TLS certificate. TODO: confirm the record and the certificate.
- **EDID:** TODO: check whether the OptiPlex (`pvenode1`) console shows correctly through the KVM. The old HDMI switch had EDID problems with it (see [Peripherals](#peripherals)).

Reach the web UI:

```bash
# from the LAN or over Tailscale (needs split DNS for home.capilabs.dev)
curl -kI https://kvm.home.capilabs.dev
curl -kI https://192.168.1.79
```

VLAN 1 (`192.168.1.0/24`) isn't advertised on Tailscale (see [subnet routes](ip-plan.md#subnet-routes)), so off the LAN the KVM is unreachable unless that changes. TODO: decide on remote access (advertise a /32 route for `192.168.1.79`, or use GL.iNet's own cloud/app access).

## Power

| Device | Details |
|---|---|
| Forza BT-601 UPS | 600 VA, manual shutdown. Est. ~15–25 min at 60–120 W load. TODO: automated shutdown (NUT?) |

Utility: Air-e, ~900 COP/kWh. Full stack estimated at ~60 kWh/month.

## Peripherals

- HDMI switch has EDID issues with the OptiPlex Proxmox console. Fix options: TESmart switch with per-port EDID emulation, or an inline EDID emulator dongle. TODO: check whether the [Comet X KVM](#remote-management-kvm) replaces the HDMI switch.

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
| ether6–7 | Unused (defconf) | 1 | — | — | Down |
| ether8 | Uplink to SODOLA port 8 (2026-11-27). TODO: re-check PVID/VLANs, still defconf? | 1 | 1 | — | Up |
| sfp-sfpplus1–2 | Unused (defconf) | 1 | — | — | Down |

The bridge itself is tagged on VLANs 10, 20, 30, and 40, so the switch has an L3 interface on each: `vlan-10`–`vlan-40` with `192.168.10.1`–`192.168.40.1`, the gateways for those VLANs. Management is `192.168.1.2` on `bridge` (VLAN 1). Full list in the [IP plan](ip-plan.md#vlans).

`pvemaster1`, `pvenode1` and `pvenode2` are on `ether2`, `ether3` and `ether4`. `ether4` is already in the VLAN table exactly like `ether2`/`ether3` (VLAN 1 untagged, VLANs 10–40 tagged). For reference, the commands that set this up:

```
/interface bridge vlan set [find vlan-ids=1]  untagged=bridge,ether1,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=10] tagged=bridge,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=20] tagged=bridge,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=30] tagged=bridge,ether2,ether3,ether4
/interface bridge vlan set [find vlan-ids=40] tagged=bridge,ether2,ether3,ether4
```

The port comments on the switch match the current devices: `ether2` was relabelled `pvemaster1 (HP Elite Mini 800 G9) - trunk` on 2026-10-27, after the hardware swap.

## SODOLA port map

SODOLA SL902-SWTGW218AS (`192.168.1.3`). Source: the owner, 2026-11-27. TODO: check the VLAN columns on the switch's web UI.

| Port | Device | MAC | VLANs | Purpose |
|---|---|---|---|---|
| 1 | `pvemaster1` onboard `eno1` | `7c:57:58:5d:a2:e4` | 1 untagged (TODO: verify) | [Wake-on-LAN](../network/usb-2.5g-adapters.md#wake-on-lan-onboard-nics) |
| 2 | `pvenode1` onboard `nic0` | `20:88:10:97:b9:44` | 1 untagged (TODO: verify) | [Wake-on-LAN](../network/usb-2.5g-adapters.md#wake-on-lan-onboard-nics) |
| 3 | `pvenode2` onboard `nic0` | `30:13:8b:81:e4:a8` | 1 untagged (TODO: verify) | [Wake-on-LAN](../network/usb-2.5g-adapters.md#wake-on-lan-onboard-nics) |
| 4–7 | TODO | — | — | — |
| 8 | Uplink to MikroTik `ether8` | — | 1 untagged (TODO: verify) | Uplink |

For the onboard NICs to be usable for failback or the [active-backup bond](../network/usb-2.5g-adapters.md#future-enhancement-active-backup-bond), ports 1–3 and 8 (and MikroTik `ether8`) also need VLANs 10, 20, 30, 40 tagged.
