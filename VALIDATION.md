# Validation Cheatsheet

Copy/paste commands to verify the stack quickly.

## Hub (Server 1)

```bash
# Compose services
docker compose -f docker-compose.hub.yml ps

# Core HTTP checks
curl -s http://localhost:9090/api/v1/status/runtimeinfo | jq '.status'    # Prometheus
curl -s "http://localhost:3100/ready"                                     # Loki

# Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'

# Loki labels
curl -s "http://localhost:3100/loki/api/v1/label/job/values"
```

## Agent (Server 2)

```bash
# Compose services
docker compose -f docker-compose.agent.yml ps

# Node exporter
curl -s http://localhost:9100/metrics | head -n 5

# Promtail logs
docker logs --tail=100 promtail

# Connectivity to hub (Loki)
curl -s "http://185.252.234.29:3100/ready"
```

## Host monitors

```bash
# auditd
sudo systemctl is-active auditd
sudo tail -n 50 /var/log/audit/audit.log

# inotify-watch service
sudo systemctl is-active inotify-watch
sudo tail -n 50 /var/log/inotify-changes.log

# AIDE baseline
sudo ls -lh /var/lib/aide/aide.db
```

## Kibana searches (examples)

- Open Kibana → Discover → Index pattern `logs-*`
- KQL:
  - `server: "<server2-hostname>" and log_type: "audit"`
  - `server: "<server2-hostname>" and log_type: "inotify"`
  - `server: "<server2-hostname>" and container.name: "<name>"`

## Resource and disk

```bash
# Memory/disk quick view
free -m | awk 'NR==2{printf "%dMB/%dMB (%d%%)\n", $3, $2, ($3*100)/$2}'
df -h /

# Prometheus retention (current flags)
cat prometheus/prometheus.yml | sed -n '1,80p'
```

## Cleanup / restart snippets

```bash
# Restart hub services
docker compose -f docker-compose.hub.yml up -d --pull always

# Restart agent services
docker compose -f docker-compose.agent.yml up -d --pull always

# Remove old docker images (optional)
docker image prune -af
```
