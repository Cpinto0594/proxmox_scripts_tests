# Decisions (ADRs)

Short records of why something is the way it is. New file per decision: `NNNN-short-title.md`, using the template below. Superseded decisions stay, marked as such.

| # | Decision | Status |
|---|---|---|
| [0001](0001-mikrotik-switch.md) | MikroTik CRS310 as core switch | Accepted |
| [0002](0002-forgejo-over-gitlab.md) | Forgejo instead of GitLab CE | Accepted |
| [0003](0003-ugos-over-truenas.md) | Keep UGOS on the NAS, not TrueNAS | Accepted |
| [0004](0004-single-instance-dbs-in-dokploy.md) | Single-instance DBs in Dokploy; HA labs on VMs | Accepted |
| [0005](0005-exposure-tunnel-plus-tailscale.md) | Cloudflare Tunnel for public, Tailscale for private | Accepted |
| [0006](0006-named-bind-volumes.md) | Named volumes with local bind driver | Accepted |
| [0007](0007-dns-on-dedicated-lxc.md) | Technitium on its own LXC | Accepted |
| [0008](0008-wings-outside-swarm.md) | Pterodactyl Wings outside Dokploy/Swarm | Proposed |

## Template

```markdown
# NNNN — Title
**Date:** YYYY-MM-DD · **Status:** Proposed | Accepted | Superseded by NNNN

## Context
## Options considered
## Decision
## Consequences
```
