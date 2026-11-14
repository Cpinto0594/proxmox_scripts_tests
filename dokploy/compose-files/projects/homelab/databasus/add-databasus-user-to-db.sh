
export POSTGRES_USER=           # an admin role that can CREATE ROLE
export POSTGRES_DB=tenantos_registrar
export DATABASUS_BACKUP_USER=databasus_backups
export DATABASUS_BACKUP_PASSWORD=''

# optional, if the server isn't on the local socket
export PGHOST=192.168.40.115
export PGPORT=5432
export PGPASSWORD=''       # password for POSTGRES_USER

sh ./init-db-script.sh

