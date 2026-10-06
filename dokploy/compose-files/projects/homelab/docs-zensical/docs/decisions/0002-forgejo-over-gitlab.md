# 0002 — Forgejo instead of GitLab CE
**Date:** TODO · **Status:** Accepted

## Context
GitLab CE with its container registry was deployed and working at `gitlab.homelab.capilabs.dev`.

## Options considered
Keep GitLab CE; move to Forgejo.

## Decision
Forgejo — Git hosting, Actions CI/CD, and a multi-format package registry, at a fraction of GitLab's resource footprint. TODO: confirm resource reasoning.

## Consequences
Runs as Dokploy Swarm stack with Postgres + Redis, SSH on 2222. Actions runner is a separate plain Compose app with docker.sock access. GitLab retired.
