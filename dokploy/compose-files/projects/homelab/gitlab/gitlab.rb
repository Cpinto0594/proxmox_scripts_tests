external_url 'https://gitlab.homelab.capilabs.dev'

# --- Container Registry (this is the whole point) ---
registry_external_url 'https://registry.homelab.capilabs.dev'
gitlab_rails['registry_enabled'] = true
registry_nginx['listen_port'] = 5050
registry_nginx['listen_https'] = false          # TLS terminated at Cloudflare, matches your Pattern B setup
registry_nginx['proxy_set_headers'] = {
  'X-Forwarded-Proto' => 'https',
  'X-Forwarded-Ssl'   => 'on'
}

# --- Reverse proxy trust (Cloudflare Tunnel -> Dokploy-Traefik -> here) ---
nginx['listen_port'] = 80
nginx['listen_https'] = false
nginx['proxy_set_headers'] = {
  'X-Forwarded-Proto' => 'https',
  'X-Forwarded-Ssl'   => 'on'
}

# --- Git over SSH ---
gitlab_rails['gitlab_shell_ssh_port'] = 2222

# --- Resource tuning: this host also runs Postgres, Infisical, etc. ---
# Defaults assume a dedicated box with 8GB+ free; these cut GitLab's footprint
# down to something reasonable to coexist with your other services.
puma['worker_processes'] = 2
puma['per_worker_max_memory_mb'] = 850
sidekiq['max_concurrency'] = 10
postgresql['shared_buffers'] = "256MB"
postgresql['max_worker_processes'] = 4
prometheus_monitoring['enable'] = false   # bundled Prometheus/Alertmanager stack, skip it
# Note: grafana['enable'] removed — bundled Grafana was fully removed from Omnibus GitLab in 17.1

# --- Housekeeping ---
gitlab_rails['backup_keep_time'] = 604800   # 7 days
gitlab_rails['time_zone'] = 'America/Bogota'