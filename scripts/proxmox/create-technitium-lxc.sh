#!/usr/bin/env bash
# Create a Debian LXC on a Proxmox VE node and install Technitium DNS Server in it.
#
# Run as root on the Proxmox node that should host the container.
# Docs: dokploy/compose-files/projects/homelab/docs-zensical/docs/services/technitium-dns-lxc.md
#
# All settings come from environment variables (see usage below). IP and GATEWAY
# are required so the script never grabs an address that is already in use.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  IP=192.168.10.3/24 GATEWAY=192.168.10.1 ./create-technitium-lxc.sh

Required:
  IP                  Container IPv4 in CIDR form, e.g. 192.168.10.3/24
  GATEWAY             Default gateway for that VLAN

Prompted for when not set:
  CT_HOSTNAME         Container hostname, e.g. technitium-dns-2
  DNS_SERVER_DOMAIN   Technitium's own FQDN, e.g. dns2.home.capilabs.dev
  ADMIN_PASSWORD      New password for the web console 'admin' user (min. 8 chars)

Optional (default):
  CTID                Container ID (next free ID in the cluster)
  BRIDGE              vmbr1
  VLAN                10            (empty = untagged)
  CORES               1
  MEMORY              512           (MiB)
  SWAP                512           (MiB)
  DISK_GB             10
  STORAGE             local-lvm     (rootfs storage)
  TEMPLATE_STORAGE    local         (where CT templates are stored)
  TEMPLATE_PATTERN    debian-12-standard
  NAMESERVER          1.1.1.1       (the container's own resolver)
  SEARCHDOMAIN        home.capilabs.dev
  TIMEZONE            America/Bogota
  SSH_KEY_FILE        (none)        public key file for root, e.g. ~/.ssh/id_ed25519.pub
  TAGS                dns;infra
  FORWARDERS          1.1.1.1,8.8.8.8
  FORWARDER_PROTOCOL  Udp           (Udp, Tcp, Tls, Https, Quic)
  RECURSION           AllowOnlyForPrivateNetworks
  ENABLE_BLOCKING     true
  BLOCK_LIST_URLS     (none)        comma-separated
  RESTORE_BACKUP      (none)        path to a Technitium backup .zip to restore
  FORCE               0             1 = skip the "IP already answers ping" check
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

log()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33mWARN:\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[1;31mERROR:\e[0m %s\n' "$*" >&2; exit 1; }

# ---- settings ---------------------------------------------------------------
IP="${IP:-}"
GATEWAY="${GATEWAY:-}"
CT_HOSTNAME="${CT_HOSTNAME:-}"
BRIDGE="${BRIDGE:-vmbr1}"
VLAN="${VLAN-10}"
CORES="${CORES:-1}"
MEMORY="${MEMORY:-512}"
SWAP="${SWAP:-512}"
DISK_GB="${DISK_GB:-10}"
STORAGE="${STORAGE:-local-lvm}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
TEMPLATE_PATTERN="${TEMPLATE_PATTERN:-debian-12-standard}"
NAMESERVER="${NAMESERVER:-1.1.1.1}"
SEARCHDOMAIN="${SEARCHDOMAIN:-home.capilabs.dev}"
TIMEZONE="${TIMEZONE:-America/Bogota}"
SSH_KEY_FILE="${SSH_KEY_FILE:-}"
TAGS="${TAGS:-dns;infra}"
DNS_SERVER_DOMAIN="${DNS_SERVER_DOMAIN:-}"
FORWARDERS="${FORWARDERS:-1.1.1.1,8.8.8.8}"
FORWARDER_PROTOCOL="${FORWARDER_PROTOCOL:-Udp}"
RECURSION="${RECURSION:-AllowOnlyForPrivateNetworks}"
ENABLE_BLOCKING="${ENABLE_BLOCKING:-true}"
BLOCK_LIST_URLS="${BLOCK_LIST_URLS:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
RESTORE_BACKUP="${RESTORE_BACKUP:-}"
FORCE="${FORCE:-0}"

API="http://127.0.0.1:5380/api"

# ---- pre-flight checks ------------------------------------------------------
[[ $EUID -eq 0 ]] || die "run as root on a Proxmox node"
command -v pct   >/dev/null || die "pct not found - is this a Proxmox VE node?"
command -v pveam >/dev/null || die "pveam not found - is this a Proxmox VE node?"

[[ -n "$IP" ]]      || { usage; die "IP is required (CIDR, e.g. 192.168.10.3/24)"; }
[[ -n "$GATEWAY" ]] || { usage; die "GATEWAY is required"; }
[[ "$IP" == */* ]]  || die "IP must include the prefix length, e.g. ${IP}/24"
[[ -z "$SSH_KEY_FILE" || -r "$SSH_KEY_FILE" ]] || die "SSH_KEY_FILE not readable: $SSH_KEY_FILE"
[[ -z "$RESTORE_BACKUP" || -r "$RESTORE_BACKUP" ]] || die "RESTORE_BACKUP not readable: $RESTORE_BACKUP"

CTID="${CTID:-$(pvesh get /cluster/nextid)}"
if pct status "$CTID" >/dev/null 2>&1 || qm status "$CTID" >/dev/null 2>&1; then
  die "ID $CTID is already used on this node"
fi
# Also catch IDs used on other cluster nodes.
if pvesh get /cluster/resources --type vm --output-format json 2>/dev/null \
     | grep -q "\"vmid\":${CTID}[,}]"; then
  die "ID $CTID is already used in the cluster"
fi

if [[ "$FORCE" != "1" ]] && ping -c1 -W1 "${IP%/*}" >/dev/null 2>&1; then
  die "${IP%/*} already answers ping - pick a free IP or set FORCE=1"
fi

# Prompt for anything identity-related that wasn't passed in. No defaults on
# purpose: the obvious ones would clash with the production server.
if [[ -z "$CT_HOSTNAME" || -z "$DNS_SERVER_DOMAIN" || -z "$ADMIN_PASSWORD" ]] && [[ ! -t 0 ]]; then
  die "CT_HOSTNAME, DNS_SERVER_DOMAIN and ADMIN_PASSWORD must be set when not running interactively"
fi
while [[ -z "$CT_HOSTNAME" ]]; do
  read -rp "Container hostname (e.g. technitium-dns-2): " CT_HOSTNAME
done
[[ "$CT_HOSTNAME" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] \
  || die "CT_HOSTNAME must be a valid hostname (letters, digits, '-'), got: $CT_HOSTNAME"
while [[ -z "$DNS_SERVER_DOMAIN" ]]; do
  read -rp "Technitium DNS server domain (e.g. dns2.home.capilabs.dev): " DNS_SERVER_DOMAIN
done
if [[ -z "$ADMIN_PASSWORD" ]]; then
  read -rsp "New Technitium admin password: " ADMIN_PASSWORD; echo
  read -rsp "Repeat password: " pw2; echo
  [[ "$ADMIN_PASSWORD" == "$pw2" ]] || die "passwords don't match"
fi
[[ ${#ADMIN_PASSWORD} -ge 8 ]] || die "admin password must be at least 8 characters"

# ---- template ---------------------------------------------------------------
log "Looking for the latest '${TEMPLATE_PATTERN}' template"
pveam update >/dev/null || warn "pveam update failed, using the cached template list"
TEMPLATE="$(pveam available --section system | awk '{print $2}' \
            | grep -E "^${TEMPLATE_PATTERN}" | sort -V | tail -n1 || true)"
[[ -n "$TEMPLATE" ]] || die "no template matches '${TEMPLATE_PATTERN}' (see: pveam available --section system)"

if pveam list "$TEMPLATE_STORAGE" | grep -q "vztmpl/${TEMPLATE}"; then
  log "Template already present: ${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}"
else
  log "Downloading ${TEMPLATE} to ${TEMPLATE_STORAGE}"
  pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
fi

# ---- create the container ---------------------------------------------------
NET0="name=eth0,bridge=${BRIDGE},ip=${IP},gw=${GATEWAY},firewall=0"
[[ -n "$VLAN" ]] && NET0+=",tag=${VLAN}"

create_args=(
  "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}"
  --hostname "$CT_HOSTNAME"
  --cores "$CORES" --memory "$MEMORY" --swap "$SWAP"
  --rootfs "${STORAGE}:${DISK_GB}"
  --net0 "$NET0"
  --nameserver "$NAMESERVER" --searchdomain "$SEARCHDOMAIN"
  --timezone "$TIMEZONE"
  --unprivileged 1 --features nesting=1
  --onboot 1 --startup order=1
  --ostype debian
  --tags "$TAGS"
  --description "Technitium DNS Server - created by scripts/proxmox/create-technitium-lxc.sh"
)
[[ -n "$SSH_KEY_FILE" ]] && create_args+=(--ssh-public-keys "$SSH_KEY_FILE")

log "Creating LXC ${CTID} (${CT_HOSTNAME}) on $(hostname) - ${IP}, VLAN ${VLAN:-untagged}"
pct create "${create_args[@]}"
pct start "$CTID"

log "Waiting for the container network"
for _ in $(seq 1 30); do
  pct exec "$CTID" -- getent hosts download.technitium.com >/dev/null 2>&1 && break
  sleep 2
done
pct exec "$CTID" -- getent hosts download.technitium.com >/dev/null 2>&1 \
  || die "container ${CTID} can't resolve download.technitium.com - check IP/GATEWAY/VLAN/NAMESERVER"

# ---- install Technitium -----------------------------------------------------
log "Updating Debian and installing curl, jq, dnsutils"
pct exec "$CTID" -- bash -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get -y -qq upgrade
  apt-get -y -qq install curl ca-certificates jq dnsutils
'

log "Running the official Technitium installer"
pct exec "$CTID" -- bash -c 'curl -sSfL https://download.technitium.com/dns/install.sh | bash'

log "Waiting for the Technitium web service on :5380"
for _ in $(seq 1 60); do
  pct exec "$CTID" -- curl -fsS -o /dev/null "http://127.0.0.1:5380/" 2>/dev/null && break
  sleep 2
done
pct exec "$CTID" -- curl -fsS -o /dev/null "http://127.0.0.1:5380/" \
  || die "Technitium web service did not come up (pct exec ${CTID} -- systemctl status dns)"

# ---- configure through the API ----------------------------------------------
# Run curl inside the container and fail unless the API answers status=ok.
api() {
  local out
  out="$(pct exec "$CTID" -- curl -fsS "$@")" || die "API call failed: ${*: -1}"
  [[ "$(jq -r .status <<<"$out")" == "ok" ]] || die "API error: $(jq -c . <<<"$out")"
  printf '%s' "$out"
}

log "Logging in with the default admin/admin"
TOKEN="$(api -X POST "${API}/user/login" \
          --data-urlencode user=admin --data-urlencode pass=admin | jq -r .token)"
AUTH=(-H "Authorization: Bearer ${TOKEN}")

log "Changing the admin password"
# Password goes in over stdin so it never shows up in a process list.
printf '%s' "$ADMIN_PASSWORD" | pct exec "$CTID" -- curl -fsS "${AUTH[@]}" -X POST \
    "${API}/user/changePassword" --data-urlencode pass=admin --data-urlencode "newPass@-" \
  | jq -e '.status == "ok"' >/dev/null || die "changing the admin password failed"

log "Applying DNS settings"
settings=(
  --data-urlencode "dnsServerDomain=${DNS_SERVER_DOMAIN}"
  --data-urlencode "forwarders=${FORWARDERS}"
  --data-urlencode "forwarderProtocol=${FORWARDER_PROTOCOL}"
  --data-urlencode "recursion=${RECURSION}"
  --data-urlencode "enableBlocking=${ENABLE_BLOCKING}"
  --data-urlencode "useLocalTime=true"
)
[[ -n "$BLOCK_LIST_URLS" ]] && settings+=(--data-urlencode "blockListUrls=${BLOCK_LIST_URLS}")
api "${AUTH[@]}" -X POST "${API}/settings/set" "${settings[@]}" >/dev/null

if [[ -n "$RESTORE_BACKUP" ]]; then
  log "Restoring backup ${RESTORE_BACKUP}"
  pct push "$CTID" "$RESTORE_BACKUP" /root/technitium-backup.zip --perms 600
  restore_q="zones=true&allowedZones=true&blockedZones=true&dnsSettings=true&logSettings=true"
  restore_q+="&authConfig=true&apps=true&scopes=true&deleteExistingFiles=true"
  api "${AUTH[@]}" -X POST -F "file=@/root/technitium-backup.zip" \
      "${API}/settings/restore?${restore_q}" >/dev/null
  pct exec "$CTID" -- rm -f /root/technitium-backup.zip
  warn "Backup restored with authConfig=true: the admin password is now the one from the backup."
fi

pct exec "$CTID" -- curl -fsS "${AUTH[@]}" -X POST "${API}/user/logout" >/dev/null 2>&1 || true

# ---- smoke test -------------------------------------------------------------
log "Smoke test: resolving example.com through the new server"
if answer="$(pct exec "$CTID" -- dig +short +time=3 @127.0.0.1 example.com A)" && [[ -n "$answer" ]]; then
  echo "$answer"
else
  warn "dig returned nothing - check forwarders and the container's outbound DNS"
fi

cat <<EOF

Done.
  Container : ${CTID} (${CT_HOSTNAME}) on $(hostname)
  DNS       : ${IP%/*}:53 (udp/tcp)
  Console   : http://${IP%/*}:5380  (user: admin)

Next: see the "After install" section of docs/services/technitium-dns-lxc.md.
EOF
