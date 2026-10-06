# 0006 — Named volumes with local bind driver
**Date:** TODO · **Status:** Accepted

## Decision
New Dokploy compose files declare named volumes using `driver: local` with `type: none, o: bind, device: /mnt/docker-storage/...` instead of direct bind mounts.

## Consequences
Data lives at a known host path (easy backups, inspectable), while compose files keep volume semantics. Host directory must exist before deploy.
