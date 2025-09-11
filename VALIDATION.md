# Validation Cheatsheet

Copy/paste commands to verify the stack quickly.

## Hub (Server 1)

```bash
# Compose services
docker-compose -f docker-compose.hub.yml ps

# Core HTTP checks
curl -s http://localhost:5601/api/status | jq '.status.overall.state'     # Kibana
curl -s http://localhost:9200/_cluster/health | jq '.status'              # Elasticsearch
curl -s http://localhost:9090/api/v1/status/runtimeinfo | jq '.status'    # Prometheus

# Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'

# Logstash logs
docker logs --tail=100 logstash

# Indices present
curl -s http://localhost:9200/_cat/indices/logs-* | tail -n 10
```

## Agent (Server 2)

```bash
# Compose services
docker-compose -f docker-compose.agent.yml ps

# Node exporter
curl -s http://localhost:9100/metrics | head -n 5

# Filebeat logs
docker logs --tail=100 filebeat

# Connectivity to hub
nc -z 185.252.234.29 5044 || bash -c 'cat < /dev/null > /dev/tcp/185.252.234.29/5044' && echo OK || echo FAIL
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
docker-compose -f docker-compose.hub.yml up -d --pull always

# Restart agent services
docker-compose -f docker-compose.agent.yml up -d --pull always

# Remove old docker images (optional)
docker image prune -af
```
