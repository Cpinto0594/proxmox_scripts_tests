# 0007 — Technitium on its own LXC
**Date:** TODO · **Status:** Accepted

## Context
Technitium ran in Docker Compose on `docker-dev-1`.

## Decision
Move it to a dedicated Proxmox LXC running natively at 192.168.10.2.

## Consequences
DNS keeps working when the Swarm/Dokploy stack is broken or being rebuilt — which is exactly when you need it.
