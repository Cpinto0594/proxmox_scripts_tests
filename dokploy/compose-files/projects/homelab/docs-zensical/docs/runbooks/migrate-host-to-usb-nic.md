# Migrate a Proxmox node to the USB 2.5G adapter

Done on `master1`, then `pvenode1`. Have console access (watch for the HDMI EDID issue on the OptiPlex).

1. Plug in the adapter, confirm the interface name: `ip -br link` (e.g. `enx6c1ff7cd73a6`).
2. Cable it to a switch trunk port carrying VLAN 1 + 10/20/30/40.
3. Create `vmbr1` on the USB interface as a VLAN-aware bridge, no IP. Apply, confirm it's up.
4. Move VLAN host IPs (`vmbr1.10`, `.20`, `.30`, `.40`) to `vmbr1`. Test each.
5. Move management IP + gateway from `vmbr0` to `vmbr1`. Test from another host — and confirm corosync/cluster status.
6. Leave `vmbr0`/`nic0` configured with **no IP** as fallback.
7. iperf3 to the other node to verify ~2.35 Gbit/s.
8. Update [hardware.md](../inventory/hardware.md) and [ip-plan.md](../inventory/ip-plan.md).

TODO: paste the final `/etc/network/interfaces` for each node.
