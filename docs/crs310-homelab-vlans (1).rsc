########################################################################
# MikroTik CRS310-8G+2S+IN - Homelab VLAN config
# VLAN 1  = existing home LAN (192.168.1.0/24) - unchanged, uplink to router
# VLAN 10 = Management        (192.168.10.0/24)
# VLAN 20 = Storage/NAS       (192.168.20.0/24)
# VLAN 30 = Kubernetes        (192.168.30.0/24)
# VLAN 40 = Other Apps        (192.168.40.0/24)
#
# IMPORTANT - apply in this order and keep a console/WinBox-over-MAC
# fallback available. If you get locked out, use MikroTik's Netinstall
# or reset-to-defaults via the reset button.
########################################################################

# --- 1. Bridge (build tagging first, enable vlan-filtering LAST) ---
/interface bridge
add name=bridge1 vlan-filtering=no comment="main switch bridge"

/interface bridge port
add bridge=bridge1 interface=ether1 pvid=1   comment="uplink to home router"
add bridge=bridge1 interface=ether2 pvid=1   comment="master1 (HP Pro Mini) - trunk"
add bridge=bridge1 interface=ether3 pvid=1   comment="pvenode1 (Dell OptiPlex) - trunk"
add bridge=bridge1 interface=ether4 pvid=1   comment="reserved: HP Elite Mini 800 G9 - trunk"
add bridge=bridge1 interface=ether5 pvid=20  comment="UGREEN DXP2800 NAS - access VLAN20"
add bridge=bridge1 interface=ether6 pvid=1   comment="general LAN"
add bridge=bridge1 interface=ether7 pvid=1   comment="general LAN"
add bridge=bridge1 interface=ether8 pvid=1   comment="general LAN"
add bridge=bridge1 interface=sfp-sfpplus1 pvid=1 comment="reserved - future 10G link"
add bridge=bridge1 interface=sfp-sfpplus2 pvid=1 comment="reserved - future 10G link"

# --- 2. VLAN table (tagged/untagged membership) ---
/interface bridge vlan
add bridge=bridge1 vlan-ids=1 \
    untagged=ether1,ether2,ether3,ether4,ether6,ether7,ether8,sfp-sfpplus1,sfp-sfpplus2 \
add bridge=bridge1 vlan-ids=10 \
    tagged=bridge1,ether2,ether3,ether4
add bridge=bridge1 vlan-ids=20 \
    tagged=bridge1,ether2,ether3,ether4 \
    untagged=ether5
add bridge=bridge1 vlan-ids=30 \
    tagged=bridge1,ether2,ether3,ether4
add bridge=bridge1 vlan-ids=40 \
    tagged=bridge1,ether2,ether3,ether4

# --- 3. Verify cabling/tagging, THEN enable filtering ---
/interface bridge set bridge1 vlan-filtering=yes

# --- 4. L3 interfaces for routing between VLANs ---
/interface vlan
add name=vlan10-mgmt    interface=bridge1 vlan-id=10
add name=vlan20-storage interface=bridge1 vlan-id=20
add name=vlan30-k8s     interface=bridge1 vlan-id=30
add name=vlan40-apps    interface=bridge1 vlan-id=40

# --- 5. IP addressing ---
/ip address
add address=192.168.1.2/24    interface=bridge1        comment="switch mgmt on existing LAN"
add address=192.168.10.1/24   interface=vlan10-mgmt    comment="mgmt gateway"
add address=192.168.20.1/24   interface=vlan20-storage comment="storage gateway"
add address=192.168.30.1/24   interface=vlan30-k8s     comment="k8s gateway"
add address=192.168.40.1/24   interface=vlan40-apps    comment="General Apps"

# --- 6. Default route via your existing home router ---
/ip route
add dst-address=0.0.0.0/0 gateway=192.168.1.1

# --- 7. NAT: let VLAN 10/20/30 reach the internet via VLAN1 uplink ---
/ip firewall nat
add chain=srcnat src-address=192.168.10.0/24 out-interface=bridge1 action=masquerade comment="mgmt -> internet"
add chain=srcnat src-address=192.168.20.0/24 out-interface=bridge1 action=masquerade comment="storage -> internet"
add chain=srcnat src-address=192.168.30.0/24 out-interface=bridge1 action=masquerade comment="k8s -> internet"
add chain=srcnat src-address=192.168.40.0/24 out-interface=bridge1 action=masquerade comment="apps -> internet"

# --- 8. Optional DHCP per VLAN (skip for k8s nodes if you prefer static IPs) ---
/ip pool
add name=pool-mgmt    ranges=192.168.10.100-192.168.10.200
add name=pool-storage ranges=192.168.20.100-192.168.20.200
add name=pool-k8s     ranges=192.168.30.100-192.168.30.199
add name=pool-apps    ranges=192.168.40.100-192.168.40.199

/ip dhcp-server
add name=dhcp-mgmt    interface=vlan10-mgmt    address-pool=pool-mgmt    lease-time=1d disabled=no
add name=dhcp-storage interface=vlan20-storage address-pool=pool-storage lease-time=1d disabled=no
add name=dhcp-k8s     interface=vlan30-k8s     address-pool=pool-k8s     lease-time=1d disabled=no
add name=dhcp-apps    interface=vlan40-apps    address-pool=pool-apps    lease-time=1d disabled=no

/ip dns 
set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8

/ip dhcp-server network
add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=192.168.10.1,1.1.1.1
add address=192.168.20.0/24 gateway=192.168.20.1 dns-server=192.168.20.1,1.1.1.1
add address=192.168.30.0/24 gateway=192.168.30.1 dns-server=192.168.30.1,1.1.1.1
add address=192.168.40.0/24 gateway=192.168.40.1 dns-server=192.168.40.1,1.1.1.1

# --- 9. Basic protection: don't let storage/k8s VLANs manage the switch ---
/ip firewall filter
add chain=input action=accept connection-state=established,related
add chain=input action=accept protocol=icmp
add chain=input action=accept in-interface=bridge1
add chain=input action=accept in-interface=vlan10-mgmt
add chain=input action=drop   in-interface=vlan20-storage comment="no switch mgmt from storage VLAN"
add chain=input action=drop   in-interface=vlan30-k8s     comment="no switch mgmt from k8s VLAN"
add chain=input action=drop   in-interface=vlan40-apps    comment="no switch mgmt from apps VLAN"
add chain=input action=drop   in-interface-list=!all comment="fallback drop - review before enabling"


#Add a Routing in my ISP router to allow trafic from my network into the router .1.2 and go into each vlans networks 
#modify all the proxmox nodes to add the vlans on its config, dont forget to also modify the vmbr0 interface adding all the vlans