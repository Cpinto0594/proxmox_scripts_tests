#### Add DATABASUS_BACKUP_USER and DATABASUS_BACKUP_PASSWORD to the container environment variables in docker-compose.yml, then run this script to create the user and grant it read-only access to the database.

#!/bin/sh
set -e

psql -v ON_ERROR_STOP=1 \
     -v app_user="${DATABASUS_BACKUP_USER}" \
     -v app_password="${DATABASUS_BACKUP_PASSWORD}" \
     -v dbname="${POSTGRES_DB}" \
     --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-'EOSQL'
    CREATE ROLE :"app_user" WITH
        LOGIN
        PASSWORD :'app_password'
        NOSUPERUSER
        NOCREATEDB
        NOCREATEROLE
        NOBYPASSRLS
        REPLICATION;

    GRANT CONNECT ON DATABASE :"dbname" TO :"app_user";
    GRANT USAGE ON SCHEMA public TO :"app_user";
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"app_user";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO :"app_user";

    -- Schema-level CREATE is already off-by-default for non-owners on
    -- Postgres 15+ (what you're running) — explicit anyway, for clarity.
    REVOKE CREATE ON SCHEMA public FROM :"app_user";

    -- NOTE: this is a DATABASE-WIDE default, not specific to this role —
    -- it revokes the TEMP privilege Postgres grants to PUBLIC (i.e. every
    -- role) by default on every new database. Affects all current and
    -- future roles connecting to this database, not just the backup user.
    REVOKE TEMP ON DATABASE :"dbname" FROM PUBLIC;
EOSQL