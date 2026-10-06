# 0008 — Pterodactyl Wings outside Dokploy/Swarm
**Date:** TODO · **Status:** Proposed

## Decision
Panel runs in Dokploy on `docker-worker-1` (MariaDB + Redis). Wings runs as plain Docker Compose on its own dedicated node.

## Why
Wings needs host networking, privileged mode, and the Docker socket to manage game-server containers — a poor fit for Swarm services.
