# Work log

Chronological record of work done on the homelab and this repo, newest first.
Each entry: what changed, why, files touched, and follow-ups. Keep the detailed
"how" on the relevant topic page and link to it from here.

---

## 2026-11-08 — Technitium LXC script: more required settings

**What:** `CT_HOSTNAME`, `DNS_SERVER_DOMAIN` and `ADMIN_PASSWORD` are now required
(no defaults) in `scripts/proxmox/create-technitium-lxc.sh`. The interactive password
prompt was removed; set the password with `read -rs ADMIN_PASSWORD` first.
`CT_HOSTNAME` is checked to be a valid hostname.

**Why:** Defaults (`technitium-dns`, `dns.home.capilabs.dev`) matched the production
server, so a second server could end up with the same identity by accident.

**Files:** `scripts/proxmox/create-technitium-lxc.sh`,
`docs-zensical/docs/services/technitium-dns-lxc.md`

**Follow-ups:** none new.

---

## 2026-11-08 — Technitium DNS LXC install script

**What:** Script to create a Technitium DNS Server in a new Proxmox LXC, so the
DNS server (LXC 108) can be rebuilt or a second one added in one command.

- `scripts/proxmox/create-technitium-lxc.sh`: creates an unprivileged Debian 12
  LXC on `vmbr1` + VLAN tag, runs the official Technitium installer, then uses the
  Technitium HTTP API to change the admin password, apply DNS settings (same
  defaults as the old Docker compose) and optionally restore a backup `.zip`.
- New page [Technitium DNS in an LXC](services/technitium-dns-lxc.md): usage,
  options, post-install, migration/cut-over of LXC 108, upgrades, troubleshooting.
- Linked from Services, Network → DNS, and the site nav.
- Fixed the "Database Clusters" nav entry in `zensical.toml` (newline inside an
  inline table, invalid TOML 1.0). Site builds clean with `zensical build`.

**Why:** LXC 108 was set up by hand and nothing recorded how to rebuild it.

**Tested:** `bash -n`, `shellcheck`, and a dry run with stand-ins for
`pct`/`pveam`/`pvesh`. Not yet run on a real Proxmox node.

**Files:** `scripts/proxmox/create-technitium-lxc.sh`,
`docs-zensical/docs/services/technitium-dns-lxc.md`, `docs-zensical/zensical.toml`,
`docs-zensical/docs/services/README.md`, `docs-zensical/docs/network/README.md`, `README.md`

**Follow-ups:**

- [ ] First real run on a Proxmox node; update the status note on the page.
- [ ] Confirm the VLAN 10 gateway (still `TODO` in the IP plan).
- [ ] Confirm the Infisical path for the Technitium admin password.

---

## 2026-11-08 — Documentation workflow

**What:** Set up a rule that every piece of work gets documented.

- Added `CLAUDE.md` at the repo root with documentation conventions so every
  AI-assisted session updates the docs as part of the change.
- Added this work log page and linked it in the site nav.

**Files:** `CLAUDE.md`, `docs-zensical/docs/worklog.md`, `docs-zensical/zensical.toml`

**Follow-ups:** none.
