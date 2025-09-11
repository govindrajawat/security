# Security Stack: Hub (Server 1) + Agents (Server 2-7)

This repo bootstraps a lightweight monitoring and security stack:

- Host: auditd + inotify + AIDE
- Logs: Filebeat → Logstash → Elasticsearch → Kibana (ELK)
- Metrics: Node Exporter → Prometheus → Grafana + Alertmanager
- IPS: Fail2Ban (optional profile)
- Runtime: Falco (optional) and Trivy (on-demand)
- Secrets: Vault (optional)

Minimal resource tuning is applied for low-spec servers.

## Topology

- Server 1 (hub: 185.252.234.29)
  - Runs ELK, Prometheus, Grafana, Alertmanager, Filebeat, optional Fail2Ban/Falco/Trivy/Vault
- Servers 2-7 (agents: e.g., 84.46.255.10)
  - Run Filebeat (forward logs to hub), Node Exporter; host runs auditd, inotify, AIDE

## Prerequisites

- Docker and Docker Compose on all servers
- Outbound from agents to hub: 185.252.234.29:5044 (Logstash)
- Open on hub (inbound): 5044/tcp, 5601/tcp, 9090/tcp, 9093/tcp, 3000/tcp
- Keep 9200 (Elasticsearch) closed externally unless required

## Quick start

### Server 1 (hub)

```bash
chmod +x *.sh
./bootstrap-hub.sh
./check-status.sh hub
```

Access:
- Kibana: http://SERVER1:5601
- Prometheus: http://SERVER1:9090
- Grafana: http://SERVER1:3000 (admin/admin123)

### Server 2 (agent)

```bash
chmod +x *.sh
SERVER1_IP=185.252.234.29 ./bootstrap-agent.sh
./deploy-monitor.sh
./check-status.sh agent
```

## Files overview

- Hub (Server 1):
  - `docker-compose.hub.yml` — hub services
  - `setup-configs.sh` — generates Prometheus, Alertmanager, Logstash, Filebeat, Falco configs
  - `bootstrap-hub.sh` — runs hub configs + compose stack + status
  - `deploy-monitor.sh` — host-only: auditd, inotify, AIDE (works on all servers)
  - `check-status.sh` — health checks for hub or agent
- Agents (Server 2-7):
  - `docker-compose.agent.yml` — agent services (Filebeat, Node Exporter, optional Fail2Ban)
  - `setup-agent.sh` — creates Filebeat config; reads SERVER1_IP env; tags with hostname
  - `bootstrap-agent.sh` — generates configs, starts agent services, status

## Validation and test commands

### Hub service health

```bash
docker-compose -f docker-compose.hub.yml ps
./check-status.sh hub
curl -s http://localhost:9200/_cat/indices/logs-* | tail -n 5
```

### Prometheus targets

- UI: http://SERVER1:9090 → Status → Targets → `node-exporters`
- CLI:
```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {health: .health, labels: .labels}'
```

### Kibana logs from Server 2

- UI: Kibana → Discover → Index pattern `logs-*`
- Filter examples (KQL):
  - `server: "<server2-hostname>" and log_type: "audit"`
  - `server: "<server2-hostname>" and log_type: "inotify"`
  - `server: "<server2-hostname>" and container.name: "<container>"`
- CLI counts:
```bash
# All Server 2 logs
curl -s 'http://localhost:9200/logs-*/_search' -H 'Content-Type: application/json' -d '{"track_total_hits":true,"query":{"term":{"server.keyword":"<server2-hostname>"}},"size":0}' | jq '.hits.total'

# Auditd only
curl -s 'http://localhost:9200/logs-*/_search' -H 'Content-Type: application/json' -d '{"track_total_hits":true,"query":{"bool":{"must":[{"term":{"server.keyword":"<server2-hostname>"}},{"term":{"log_type.keyword":"audit"}}]}},"size":0}' | jq '.hits.total'
```

### Agent checks (Server 2)

```bash
docker-compose -f docker-compose.agent.yml ps
./check-status.sh agent
# Filebeat logs
docker logs --tail=100 filebeat
# Node exporter
curl -s http://localhost:9100/metrics | head -n 5
# Logstash connectivity test
nc -z 185.252.234.29 5044 || bash -c 'cat < /dev/null > /dev/tcp/185.252.234.29/5044' && echo OK || echo FAIL
```

### Host monitors

```bash
# auditd
sudo systemctl status auditd
sudo tail -n 50 /var/log/audit/audit.log
# inotify watcher
sudo systemctl status inotify-watch.service
sudo tail -n 50 /var/log/inotify-changes.log
# AIDE baseline
sudo ls -lh /var/lib/aide/aide.db
```

## Operations

### Change Grafana admin password

- Edit `docker-compose.hub.yml` `GF_SECURITY_ADMIN_PASSWORD`, then:
```bash
docker-compose -f docker-compose.hub.yml up -d grafana
```

### Start optional profiles

```bash
docker-compose -f docker-compose.hub.yml --profile ips up -d     # Fail2Ban
docker-compose -f docker-compose.hub.yml --profile runtime up -d # Falco + Trivy
docker-compose -f docker-compose.hub.yml --profile secrets up -d # Vault
```

### Retention and resources

- Elasticsearch: keep `ilm_enabled: false`; manage with index patterns and manual cleanup or add ILM later.
- Prometheus retention: default 30d; change via `--storage.tsdb.retention.time`.
- Disk checks:
```bash
df -h /
curl -s http://localhost:9200/_cat/indices | wc -l
```

## Troubleshooting

- No logs in Kibana from Server 2
  - Ensure agent stack running: `docker-compose -f docker-compose.agent.yml ps`
  - Filebeat can reach hub: `docker logs filebeat | tail -n 50`
  - Hub Logstash receiving: `docker logs -f logstash | head -n 50`
  - Check auditd/inotify on Server 2: see Host monitors above

- Logstash up but no indices
  - Confirm output host in `filebeat-agent.yml` (generated by `setup-agent.sh`) points to 185.252.234.29:5044
  - Check ES connectivity inside Logstash container: `curl -s http://elasticsearch:9200`

- High resource usage
  - Reduce Prometheus retention; stop optional profiles; shorten ES log retention; consider Loki for container/sys logs.

## Migration to Kubernetes (later)

- Keep host-level `deploy-monitor.sh` as-is
- Replace agent compose with DaemonSets (Filebeat/Promtail, Node Exporter, Falco)
- Keep hub in Docker or install kube-prometheus-stack/ELK via Helm

---
