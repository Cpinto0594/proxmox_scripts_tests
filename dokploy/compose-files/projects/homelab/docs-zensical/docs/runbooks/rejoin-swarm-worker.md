# Rejoin a Swarm worker

**Symptom:** `docker node ls` shows the worker `Down`, heartbeat failure.

> First check [open-items](../open-items.md): `docker-dev-1` advertises a stale address (192.168.1.103). Until that's fixed, the worker may drop again after manager-side events.

## Steps

1. On the manager, get a fresh token:
   ```bash
   docker swarm join-token worker
   ```
2. On the worker:
   ```bash
   docker swarm leave --force
   ```
3. On the manager, remove the old node entry:
   ```bash
   docker node rm <old-node-id>
   ```
4. On the worker, join with the token, advertising its VLAN 40 IP:
   ```bash
   docker swarm join --advertise-addr 192.168.40.11 --token <token> 192.168.40.10:2377
   ```
5. Verify: `docker node ls` → `Ready`. Re-apply node labels if any placement constraints use them.

## If that doesn't work

What fixed it the last time it persisted: full OS reinstall of `docker-worker-1`, then rejoin with a fresh token.
