# 0004 — Single-instance DBs in Dokploy; HA labs on VMs
**Date:** TODO · **Status:** Accepted

## Context
Considered clustering databases in Kubernetes.

## Decision
App databases run as single instances in Dokploy. HA is explored separately as learning labs on Proxmox VMs (Patroni + etcd for Postgres; Galera + MaxScale for MariaDB), not Docker, to see the moving parts directly.

## Consequences
Labs are homelab-grade, not prod. Plan: 3 VMs each, third VM moves to the third node when it arrives; revisit on Kubernetes later. Backups for single instances via Databasus.
