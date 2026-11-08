# Technitium DNS in an LXC

How to create a Technitium DNS Server in its own Proxmox LXC, using the
script in this repo: `scripts/proxmox/create-technitium-lxc.sh`.

The production DNS server (`192.168.10.2`, LXC 108 on `pvemaster1`) runs the
same way: native install in an LXC, not Docker, so DNS doesn't depend on the
Swarm stack. See [network → DNS](../network/README.md#dns).

!!! note "Status"
    The script was checked with `bash -n`, `shellcheck`, and a dry run using
    stand-ins for the Proxmox commands (2026-11-08). TODO: first real run on a
    Proxmox node. Update this note with the date and node once it has run.

## What the script does

```mermaid
flowchart TD
    A[Pre-flight checks<br/>root, pct, IP/GW given,<br/>CTID free in cluster, IP not answering ping] --> B[Ask for hostname, domain, password,<br/>container image (Debian/Ubuntu list)<br/>download image if missing]
    B --> C[pct create<br/>unprivileged, nesting=1, onboot, startup order=1<br/>vmbr1 + VLAN tag]
    C --> D[Wait for network]
    D --> E[apt upgrade + curl, jq, dnsutils]
    E --> F[Official installer<br/>download.technitium.com/dns/install.sh]
    F --> G[API: login admin/admin<br/>change admin password]
    G --> H[API: settings/set<br/>domain, forwarders, recursion, blocking]
    H --> I{RESTORE_BACKUP set?}
    I -- yes --> J[API: settings/restore]
    I -- no --> K
    J --> K[Smoke test: dig example.com @127.0.0.1]
```

- Technitium installs to `/opt/technitium/dns`, config is in `/etc/dns`, the
  systemd unit is `dns.service`.
- The container is **unprivileged** with `nesting=1` (needed by systemd in
  Debian 12 containers). It has `onboot=1` and `startup order=1`, so DNS
  starts before the other guests on that node.
- The admin password goes to the container over stdin, so it never shows up
  in a process list or in shell history (as long as you let the script prompt
  for it).

## Prerequisites

- Root shell on the Proxmox node that should host the container.
- A **free IP** for the container, and the VLAN gateway. All Proxmox nodes have
  `vmbr1` VLAN-aware and trunking VLANs 10/20/30/40
  ([proxmox.md](../platforms/proxmox.md#networking)), so `VLAN=10` works on any node.
- Outbound internet from that VLAN (Debian mirrors, `download.technitium.com`).
- TODO: confirm the VLAN 10 gateway. It is still `TODO` in the
  [IP plan](../inventory/ip-plan.md#vlans). The examples below assume `192.168.10.1`.

## Run it

Copy the script to the node (or clone this repo there):

```bash
scp scripts/proxmox/create-technitium-lxc.sh root@192.168.1.90:/root/
```

```bash
chmod +x /root/create-technitium-lxc.sh
```

On the node, create a test/secondary server on a free VLAN 10 address
(it asks for the hostname, the Technitium domain, the admin password and the
container image):

```bash
IP=192.168.10.3/24 GATEWAY=192.168.10.1 ./create-technitium-lxc.sh
```

With your SSH key, a fixed ID, and the backup from the current server restored:

```bash
CTID=109 IP=192.168.10.3/24 GATEWAY=192.168.10.1 \
SSH_KEY_FILE=/root/.ssh/authorized_keys \
RESTORE_BACKUP=/root/technitium-backup.zip \
./create-technitium-lxc.sh
```

`./create-technitium-lxc.sh --help` lists every option.

### Prompts

Anything you don't pass as a variable is asked for. Press **Enter** to take the
default in brackets:

```text
Container hostname [technitium-dns-2]:
Technitium DNS server domain [dns2.home.capilabs.dev]:
New Technitium admin password:
Repeat password:
Available container images:
   1) debian-12-standard_12.2-1_amd64.tar.zst
   2) debian-12-standard_12.7-1_amd64.tar.zst  (default)
   3) debian-13-standard_13.1-1_amd64.tar.zst
   4) ubuntu-24.04-standard_24.04-2_amd64.tar.zst
Container image - number or name [debian-12-standard_12.7-1_amd64.tar.zst]:
```

- The defaults are for a **second** server, so accepting them never copies the
  production server's identity (`technitium-dns` / `dns.home.capilabs.dev`).
- The password has no default and must be at least 8 characters.
- The image list is whatever `pveam available` offers, limited to Debian and
  Ubuntu (the script installs packages with `apt`). Type a number or the full
  name; anything else asks again. The default is the newest match for
  `TEMPLATE_PATTERN`. The list above is an example — the real one depends on
  the node.
- Without a terminal (e.g. from Ansible) nothing is asked: hostname, domain and
  image use their defaults, and `ADMIN_PASSWORD` must be set.

### Options

| Variable | Default | Notes |
|---|---|---|
| `IP` | **required** | CIDR, e.g. `192.168.10.3/24` |
| `GATEWAY` | **required** | VLAN gateway |
| `CTID` | next free ID | Checked against the whole cluster |
| `CT_HOSTNAME` | prompted, `technitium-dns-2` | Letters, digits, `-` |
| `BRIDGE` / `VLAN` | `vmbr1` / `10` | `VLAN=` (empty) for untagged |
| `CORES` / `MEMORY` / `SWAP` | `1` / `512` / `512` | Same size as LXC 108 |
| `DISK_GB` / `STORAGE` | `10` / `local-lvm` | |
| `TEMPLATE` | prompted, newest `TEMPLATE_PATTERN` match | Container image, e.g. `debian-12-standard_12.7-1_amd64.tar.zst`. Debian/Ubuntu only; `ostype` is set to match |
| `TEMPLATE_STORAGE` / `TEMPLATE_PATTERN` | `local` / `debian-12-standard` | Where images are stored / which one is the default |
| `NAMESERVER` | `1.1.1.1` | The container's **own** resolver (not itself, so installs/updates work even if Technitium is down) |
| `SEARCHDOMAIN` / `TIMEZONE` | `home.capilabs.dev` / `America/Bogota` | |
| `SSH_KEY_FILE` | none | Public key(s) for `root` |
| `TAGS` | `dns;infra` | Proxmox tags |
| `DNS_SERVER_DOMAIN` | prompted, `dns2.home.capilabs.dev` | Technitium's own FQDN. Use a different one per server |
| `FORWARDERS` / `FORWARDER_PROTOCOL` | `1.1.1.1,8.8.8.8` / `Udp` | |
| `RECURSION` | `AllowOnlyForPrivateNetworks` | |
| `ENABLE_BLOCKING` / `BLOCK_LIST_URLS` | `true` / none | |
| `ADMIN_PASSWORD` | prompted (hidden, asked twice), no default | Min. 8 chars. Store it in Infisical, e.g. `infisical:/homelab/technitium/admin-password` (TODO: confirm path) |
| `RESTORE_BACKUP` | none | Technitium backup `.zip` to restore |
| `FORCE` | `0` | `1` skips the "IP already answers ping" check |

The DNS defaults match the old Docker setup in
`dokploy/compose-files/projects/homelab/technitium/compose.yml`.

## After install

1. **Check it answers** from another machine on the LAN:

    ```bash
    dig @192.168.10.3 example.com +short
    ```

2. Open the console at `http://<ip>:5380` and log in as `admin`.
3. **Add a record in Proxmox docs**: add the container to the
   [VMs and LXCs table](../platforms/proxmox.md#vms-and-lxcs) and the
   [IP plan](../inventory/ip-plan.md#infrastructure).
4. If it should serve `*.home.capilabs.dev`, recreate (or restore) the
   `home.capilabs.dev` zone pointing at Traefik.
5. To use it as a **second DNS server**, add its IP to DHCP / the clients and
   to Tailscale split DNS (admin console → DNS → `home.capilabs.dev`).

## Migrating / rebuilding the production server

To replace LXC 108 with a fresh one, keeping its config:

1. Take a backup from the current server (API token from the console →
   Administration → Sessions → Create Token):

    ```bash
    TOKEN="<api token>"   # don't commit it
    curl -s -H "Authorization: Bearer $TOKEN" \
      "http://192.168.10.2:5380/api/settings/backup?zones=true&allowedZones=true&blockedZones=true&dnsSettings=true&logSettings=true&authConfig=true&apps=true&scopes=true" \
      -o technitium-backup.zip
    ```

2. Create the new container on a **temporary** IP with `RESTORE_BACKUP=...`.
3. Check it resolves your local zones:

    ```bash
    dig @192.168.10.3 technitium.home.capilabs.dev +short
    ```

4. Cut over: stop LXC 108, then move the new container to `192.168.10.2`:

    ```bash
    pct stop 108
    pct set <newid> --net0 name=eth0,bridge=vmbr1,tag=10,ip=192.168.10.2/24,gw=192.168.10.1,firewall=0
    pct reboot <newid>
    ```

5. Once you're happy, remove LXC 108 (`pct destroy 108`), and update the docs.

!!! warning
    The restore uses `authConfig=true`, so after it the admin password is the
    one **from the backup**, not the `ADMIN_PASSWORD` you gave the script.
    `dnsSettings=true` also brings back the old `dnsServerDomain`, forwarders
    and blocking settings.

## Upgrading Technitium

Re-running the official installer upgrades in place and keeps `/etc/dns`:

```bash
pct exec 108 -- bash -c 'curl -sSfL https://download.technitium.com/dns/install.sh | bash'
```

Take a Proxmox backup or snapshot first (`vzdump 108 --storage backups_nas --mode snapshot`).

## Troubleshooting

| Symptom | Check |
|---|---|
| "can't resolve download.technitium.com" | Wrong `GATEWAY`/`VLAN`, or the VLAN has no internet. `pct exec <id> -- ip a; ip r` |
| Web service didn't come up | `pct exec <id> -- systemctl status dns` and `journalctl -u dns` |
| Port 53 already in use | Something else in the container listens on 53: `pct exec <id> -- ss -lntup 'sport = :53'` |
| `ID ... already used in the cluster` | Pick another `CTID` or leave it unset |
