# Databasus (Postgres backups)

Scheduled backups of the Postgres databases.

| | |
|---|---|
| Compose | `dokploy/compose-files/projects/homelab/databasus/compose.yml` |
| Dokploy app | Compose · `homelab-databasus-kd3hwx` |
| Node | `docker-dev-1` |
| Image | `databasus/databasus:latest` |
| URLs | `https://databasus.homelab.capilabs.dev` (public, tunnel), `https://databasus.home.capilabs.dev` (local) |
| Host port | `9002` → `4005`, bound to `${TAILSCALE_IP}` and `${DOCKER_NODE_IP}` (`192.168.40.10`) only |
| Data | bind `/mnt/databasus-data` → `/databasus-data` |
| Limits | 1 CPU / 512 MB (backups spike CPU and RAM while compressing and encrypting) |

## Backed-up databases

- tenant-os Registrar DB and Tenants DB (see the [service catalog](README.md#tenant-os)).
- TODO: add the authentik database and the other Patroni app DBs.

## Add a backup user to a database

`add-databasus-user-to-db.sh` in the compose dir only sets the variables and then calls
`./init-db-script.sh`, which creates the backup role. TODO: `init-db-script.sh` isn't in the repo;
add it (or document where it lives).

```bash
export POSTGRES_USER=<admin-role>          # a role that can CREATE ROLE
export POSTGRES_DB=tenantos_registrar
export DATABASUS_BACKUP_USER=databasus_backups
export DATABASUS_BACKUP_PASSWORD='<from Infisical>'   # TODO: confirm the Infisical path
export PGHOST=192.168.40.115 PGPORT=5432 PGPASSWORD='<admin password>'
sh ./init-db-script.sh
```
