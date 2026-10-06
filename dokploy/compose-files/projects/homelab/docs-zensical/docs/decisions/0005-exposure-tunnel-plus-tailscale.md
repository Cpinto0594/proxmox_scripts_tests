# 0005 — Cloudflare Tunnel for public, Tailscale for private
**Date:** TODO · **Status:** Accepted

## Options considered
WireGuard, Tailscale, Headscale, Cloudflare Tunnel.

## Decision
- Public web services: Cloudflare Tunnel → Dokploy Traefik (no open inbound ports, TLS at Cloudflare).
- Private access (DB ports, admin, quorum): Tailscale installed on hosts.
- Local access: Technitium → Traefik with Cloudflare DNS-challenge certs on `home.capilabs.dev`.

## Consequences
Dedicated `homelab.capilabs.dev` subdomain avoids the free wildcard-cert depth limit. DB ports published with Swarm host mode; restricting to the tailnet needs host firewall rules.
