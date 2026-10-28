# PostgreSQL HA Cluster: Patroni + etcd + HAProxy + keepalived

Homelab build on 3 Proxmox VMs, VLAN 40. Built for learning, not hardened for production.

---

## 1. Design decisions and why

| Decision | Choice | Reason |
|---|---|---|
| Where it runs | 3 Proxmox VMs (systemd services) | Closest to how Patroni is documented, so tutorials and troubleshooting threads match your setup. Only Patroni behavior is new; no Kubernetes plumbing to debug at the same time. |
| etcd layout | One etcd member per VM (3 total), co-located with Patroni/PostgreSQL | etcd needs an odd member count for quorum. 3 members tolerate 1 failure. A 2-member cluster is worse than 1 (losing either node loses quorum). |
| Postgres bootstrap | Patroni runs `initdb`, not the OS package | Patroni must own the data dir. The default `main` cluster is dropped. |
| Stable endpoint | HAProxy (TCP mode) on every VM + keepalived VIP | HAProxy routes to whoever currently answers `/primary`. keepalived gives clients one IP that survives a VM loss. |
| Network | VLAN 40, `192.168.40.0/24` | Isolates the DB tier. Needs a VLAN-aware bridge and a trunked switch port. |
| OS | Ubuntu Server 24.04 LTS | Same distro as the rest of the homelab. PGDG apt repo supports it first-class. |

### What this architecture is and is not

- It is **high availability**: three complete copies of one dataset, one writer at a time, automatic failover.
- It is **not scale-out**: all writes go to the single leader. Replicas are read-only standbys.
- For multiple clients with independent data, use separate databases inside this cluster (shared failure domain), or build one cluster per client (full isolation).

---

## 2. Prerequisites

### Topology

| VM | Hostname | IP | Runs |
|---|---|---|---|
| VM1 | pg1 | 192.168.40.115 | etcd, Patroni/PostgreSQL, HAProxy, keepalived |
| VM2 | pg2 | 192.168.40.116 | same |
| VM3 | pg3 | 192.168.40.117 | same |

Floating VIP: `192.168.40.120`

### Sizing (per VM)

- Comfortable: 2 vCPU, 2-4 GB RAM, 20 GB disk
- Absolute floor: 1 vCPU, 1 GB RAM, 10 GB disk (no headroom once you run queries)

### Proxmox and network

- Set each VM NIC's **VLAN tag to 40**.
- `vmbr0` must be VLAN-aware on every Proxmox node.
- The switch ports facing the Proxmox nodes must trunk VLAN 40.
- If you cloned VMs from a template, check `/etc/fstab` for stale UUIDs (a boot hang waiting on `/dev/disk/by-uuid/...` is the symptom).

### Ports that must be open between the three VMs

| Port | Purpose |
|---|---|
| 2379 / 2380 | etcd client / peer |
| 8008 | Patroni REST API (also used by HAProxy health checks) |
| 5432 | PostgreSQL (replication and direct access) |
| 5000 | HAProxy listener for clients |
| VRRP (IP protocol 112) | keepalived heartbeats between the VMs |

---

## 3. Step-by-step build

### 3.1 VM prep (all three)

```bash
# /etc/hosts, identical on all three
192.168.40.115 pg1
192.168.40.116 pg2
192.168.40.117 pg3

sudo apt update && sudo apt install -y curl wget gnupg2 python3-pip python3-venv
```

### 3.2 etcd (all three)

```bash
ETCD_VER=v3.6.13   # check for the latest stable release first
cd /tmp
curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o etcd.tar.gz
tar xzf etcd.tar.gz
sudo mv etcd-${ETCD_VER}-linux-amd64/etcd /usr/local/bin/
sudo mv etcd-${ETCD_VER}-linux-amd64/etcdctl /usr/local/bin/
sudo useradd -r -s /sbin/nologin etcd
sudo mkdir -p /var/lib/etcd && sudo chown etcd:etcd /var/lib/etcd
```

`/etc/systemd/system/etcd.service` (pg1 shown). On pg2/pg3 change only `ETCD_NAME` and the four IPs in the LISTEN/ADVERTISE lines. `ETCD_INITIAL_CLUSTER` is identical on all three.

```ini
[Unit]
Description=etcd key-value store
After=network.target

[Service]
User=etcd
Type=notify
Environment=ETCD_NAME=pg1
Environment=ETCD_DATA_DIR=/var/lib/etcd
Environment=ETCD_LISTEN_PEER_URLS=http://192.168.40.115:2380
Environment=ETCD_LISTEN_CLIENT_URLS=http://192.168.40.115:2379,http://127.0.0.1:2379
Environment=ETCD_INITIAL_ADVERTISE_PEER_URLS=http://192.168.40.115:2380
Environment=ETCD_ADVERTISE_CLIENT_URLS=http://192.168.40.115:2379
Environment=ETCD_INITIAL_CLUSTER=pg1=http://192.168.40.115:2380,pg2=http://192.168.40.116:2380,pg3=http://192.168.40.117:2380
Environment=ETCD_INITIAL_CLUSTER_STATE=new
Environment=ETCD_INITIAL_CLUSTER_TOKEN=pg-etcd-cluster
ExecStart=/usr/local/bin/etcd
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Start all three at roughly the same time (they need each other to bootstrap):

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now etcd
```

Verify:

```bash
etcdctl --endpoints=http://192.168.40.115:2379,http://192.168.40.116:2379,http://192.168.40.117:2379 endpoint health
etcdctl --endpoints=http://192.168.40.115:2379 member list
```

Expect 3 healthy members.

### 3.3 PostgreSQL binaries, no initdb (all three)

```bash
sudo apt install -y postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
sudo apt install -y postgresql-17

sudo systemctl stop postgresql
sudo systemctl disable postgresql
sudo pg_dropcluster --stop 17 main
```

### 3.4 Patroni (all three)

```bash
sudo mkdir -p /etc/patroni
sudo python3 -m venv /opt/patroni-venv
sudo /opt/patroni-venv/bin/pip install --upgrade pip
sudo /opt/patroni-venv/bin/pip install 'patroni[etcd3]' psycopg2-binary
```

`/etc/patroni/config.yml` (pg1 shown). On pg2/pg3 change `name` and the two node IPs under `restapi` and `postgresql.connect_address`. `etcd3.hosts` and the `authentication` block are identical on all three.

```yaml
scope: pg-cluster
namespace: /patroni/
name: pg1

restapi:
  listen: 192.168.40.115:8008
  connect_address: 192.168.40.115:8008

etcd3:
  hosts: 192.168.40.115:2379,192.168.40.116:2379,192.168.40.117:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 10
        max_replication_slots: 10
  initdb:
    - encoding: UTF8
    - data-checksums
  pg_hba:
    - host replication repl_user 192.168.40.0/24 md5
    - host all all 192.168.40.0/24 md5

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 192.168.40.115:5432
  data_dir: /var/lib/postgresql/17/patroni
  bin_dir: /usr/lib/postgresql/17/bin
  authentication:
    replication:
      username: repl_user
      password: "CHANGE_ME"
    superuser:
      username: dbadmin
      password: "CHANGE_ME"
  parameters:
    unix_socket_directories: /var/run/postgresql

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
```

Data directory. It **must be mode 0700 and owned by `postgres`**, otherwise Postgres refuses to start:

```bash
sudo mkdir -p /var/lib/postgresql/17/patroni
sudo chown postgres:postgres /var/lib/postgresql/17/patroni
sudo chmod 0700 /var/lib/postgresql/17/patroni
```

`/etc/systemd/system/patroni.service`:

```ini
[Unit]
Description=Patroni PostgreSQL HA
After=etcd.service
Wants=etcd.service

[Service]
User=postgres
ExecStart=/opt/patroni-venv/bin/patroni /etc/patroni/config.yml
Restart=on-failure
TimeoutSec=30

[Install]
WantedBy=multi-user.target
```

Start **pg1 first** (it bootstraps the cluster), wait for it to settle, then pg2, then pg3:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now patroni
```

### 3.5 Verify the cluster

Run from any node. `patronictl` reads state from etcd, so every node shows the same view.

```bash
/opt/patroni-venv/bin/patronictl -c /etc/patroni/config.yml list
```

Expect one `Leader` and two `Replica` nodes, state `streaming`, same timeline (TL), zero lag.

### 3.6 HAProxy (all three)

```bash
sudo apt install -y haproxy
```

Append to `/etc/haproxy/haproxy.cfg` (identical on all three). **`mode tcp` is required.**

```
listen postgres_primary
  bind *:5000
  mode tcp
  option httpchk GET /primary
  http-check expect status 200
  default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
  server pg1 192.168.40.115:5432 check port 8008
  server pg2 192.168.40.116:5432 check port 8008
  server pg3 192.168.40.117:5432 check port 8008
```

```bash
sudo systemctl restart haproxy
```

### 3.7 keepalived VIP (all three)

```bash
sudo apt install -y keepalived
ip addr    # confirm the real interface name (likely ens18 on a Proxmox VM)
```

`/etc/keepalived/keepalived.conf` on **pg1**:

```
vrrp_script chk_haproxy {
    script "/usr/bin/pgrep haproxy"
    interval 2
    weight -60
    fall 3
    rise 2
}

vrrp_instance VI_1 {
    interface ens18
    state MASTER
    virtual_router_id 51
    priority 150
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass CHANGE_ME_VRRP
    }
    virtual_ipaddress {
        192.168.40.120/24
    }
    track_script {
        chk_haproxy
    }
}
```

- pg2: same file, `state BACKUP`, `priority 100`
- pg3: same file, `state BACKUP`, `priority 50`
- `virtual_router_id`, `auth_pass`, and the VIP must match on all three.
- `weight -60` matters: when HAProxy dies, the node's priority drops by 60 (150 becomes 90), which is below pg2's 100, so the VIP moves. A small positive weight would not trigger a move.

```bash
sudo systemctl enable --now keepalived
ip addr show ens18   # only one node should show 192.168.40.120
```

### 3.8 Connect

```bash
sudo apt install -y postgresql-client-17   # on whatever machine runs psql
psql -h 192.168.40.120 -p 5000 -U dbadmin -d postgres
```

---

## 4. Testing failover

**Postgres leader failover**

```bash
# on whichever node is Leader
sudo systemctl stop patroni

# from any node
/opt/patroni-venv/bin/patronictl -c /etc/patroni/config.yml list
```

A real promotion shows the **timeline incrementing** (1 to 2) on the new leader and the remaining replica. Restart the stopped node with `sudo systemctl start patroni`; with `use_pg_rewind: true` it rejoins as a replica without a full re-clone.

**VIP failover**

```bash
# on the node currently holding 192.168.40.120
sudo systemctl stop keepalived
```

The VIP should appear on pg2 within a couple of seconds. Also test killing HAProxy (`sudo systemctl stop haproxy`) to confirm the health-check script moves the VIP.

---

## 5. Considerations and gotchas

**Credentials**
- `repl_user` and `dbadmin` credentials in `bootstrap`/`authentication` only take effect on the **first bootstrap**. Changing them in `config.yml` afterwards does nothing. Use `ALTER ROLE` and update the config to match.
- The username and password must be identical on all three nodes, or replication auth fails (look in the replica's Postgres logs).
- If you rename `repl_user`, update the `pg_hba` replication line to match.
- Quote passwords in YAML if they contain `!`, `:` or `#`.
- Keep real credentials out of Git. At homelab scale, Ansible Vault or an untracked env file is enough.

**Patroni and Postgres**
- Don't let the OS Postgres service run; Patroni supervises Postgres itself.
- `use_pg_rewind` depends on data checksums (or `wal_log_hints`), which the `initdb` block enables.
- `patronictl list` is safe to run anywhere; it queries etcd, not local Postgres.
- Postgres binds `0.0.0.0:5432` on each node, which is why HAProxy listens on 5000. To use 5432 on the VIP, restrict Postgres to each node's own IP.

**etcd**
- etcd is sensitive to CPU starvation and slow fsync. An oversubscribed Proxmox host or contended storage can cause false elections and unexpected Patroni failovers. If you see a promotion you didn't trigger, check `journalctl -u etcd` first.
- Prefer local or fast storage for etcd data. NFS-backed volumes can feel sluggish.
- This build uses plain HTTP between members. Fine for a lab; add TLS later.

**HAProxy**
- Without `mode tcp`, HAProxy defaults to HTTP mode and clients fail with `received invalid response to SSL negotiation: H`.
- `option httpchk` plus `mode tcp` is intentional: HTTP health check against 8008, raw TCP data path to 5432.
- Any HAProxy port can be used. Change the `bind` line on all three VMs and restart.

**keepalived**
- Use a negative `weight` on the check script (see 3.7).
- VRRP (protocol 112) must be allowed on VLAN 40 between the VMs.

**Placement across Proxmox hosts**
- Put one VM on each Proxmox host (`pvemaster1`, `pvenode1`, `pvenode2`); if two VMs share a host, a host failure can take out a majority of etcd. To move a VM, use `qm migrate <vmid> <node>`. IP and MAC are preserved on the same VLAN, so no cluster config changes are needed.
- Offline migration drops that node briefly, like a reboot. Cluster stays up as long as the other two remain healthy.

**VLAN**
- Anything outside VLAN 40 (Kubernetes, Dokploy on `192.168.1.x`) needs an inter-VLAN rule on the MikroTik allowing only the DB port (5000) to the VIP, plus an extra `pg_hba` line for that subnet.

---

## 6. Troubleshooting log (issues hit during this build)

| Symptom | Cause | Fix |
|---|---|---|
| `data directory ... has invalid permissions` (member shows `start failed` or `stopped`) | Data dir left at default mkdir mode | `chmod 0700` and `chown postgres:postgres`, restart Patroni |
| `received invalid response to SSL negotiation: H` | HAProxy `listen` block missing `mode tcp` | Add `mode tcp`, restart HAProxy |
| `You must install at least one postgresql-client-<version> package` | No client binaries installed | `sudo apt install -y postgresql-client-17` |
| Boot hangs on `dev-disk-by-uuid-...device/start running` | Stale UUID in `/etc/fstab` (common on cloned VMs) | `blkid`, fix or comment out the stale fstab line, `mount -a` |

---

## 7. Next steps

- Add backups (pgBackRest) and TLS for etcd and Patroni's REST API.
- Add a read-only HAProxy listener using Patroni's `/replica` endpoint to spread read traffic across replicas.
- Optionally redo the same architecture on Kubernetes (StatefulSets, custom Patroni image, HAProxy for primary routing) or with an operator once the mechanics are familiar.
