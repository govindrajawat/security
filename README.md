# Security Stack: Hub (Server 1) + Agents (Server 2-7)

This repo bootstraps a lightweight monitoring and security stack:

- Host: auditd + inotify + AIDE
- Logs: Promtail → Loki → Grafana (Explore)
- Metrics: Node Exporter → Prometheus → Grafana + Alertmanager
- IPS: Fail2Ban (optional profile)
- Runtime: Falco (optional) and Trivy (on-demand)
- Secrets: Vault (optional)

Minimal resource tuning is applied for low-spec servers.

## Topology

- Server 1 (hub: 185.252.234.29)
  - Runs Loki, Prometheus, Grafana, Alertmanager, optional Fail2Ban/Falco/Trivy/Vault
- Servers 2-7 (agents: e.g., 84.46.255.10)
  - Run Promtail (forward logs to hub), Node Exporter; host runs auditd, inotify, AIDE

## Prerequisites

- Docker and Docker Compose on all servers
- Outbound from agents to hub: 185.252.234.29:3100 (Loki)
- Open on hub (inbound): 3100/tcp, 9090/tcp, 9093/tcp, 3000/tcp

## Quick start

### Server 1 (hub)

```bash
chmod +x *.sh
./bootstrap-hub.sh
./check-status.sh hub
```

Access:
- Grafana: http://SERVER1:3000 (admin/admin123)
- Prometheus: http://SERVER1:9090

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
  - `setup-configs.sh` — generates Prometheus, Alertmanager, Loki, Falco configs
  - `bootstrap-hub.sh` — runs hub configs + compose stack + status
  - `deploy-monitor.sh` — host-only: auditd, inotify, AIDE (works on all servers)
  - `check-status.sh` — health checks for hub or agent
- Agents (Server 2-7):
  - `docker-compose.agent.yml` — agent services (Promtail, Node Exporter, optional Fail2Ban)
  - `setup-agent.sh` — (still for host monitors); Promtail config is generated as promtail-agent.yml
  - `bootstrap-agent.sh` — generates configs, starts agent services, status

## Validation and test commands

### Hub service health

```bash
docker-compose -f docker-compose.hub.yml ps
./check-status.sh hub
curl -s "http://localhost:3100/loki/api/v1/label/job/values"
```

### Prometheus targets

- UI: http://SERVER1:9090 → Status → Targets → `node-exporters`
- CLI:
```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {health: .health, labels: .labels}'
```

### View logs from Server 2 in Grafana (Loki)

- Grafana → Explore → Data source: Loki
- LogQL examples:
  - `{job="varlogs", host="<server2-hostname>"}`
  - `{job="containers", host="<server2-hostname>", container_name="<name>"}` |= `"ERROR"`

### Agent checks (Server 2)

```bash
docker-compose -f docker-compose.agent.yml ps
./check-status.sh agent
# Promtail logs
docker logs --tail=100 promtail
# Node exporter
curl -s http://localhost:9100/metrics | head -n 5
# Loki connectivity test
curl -s "http://185.252.234.29:3100/ready"
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

- Loki stores chunks on disk under `loki_data`; manage via filesystem and Grafana Explore. Prometheus retention unchanged (30d by flag).
- Disk checks:
```bash
df -h /
```

## Troubleshooting

- No logs visible in Grafana Explore
  - Ensure agent stack running: `docker-compose -f docker-compose.agent.yml ps`
  - Promtail can reach hub: `docker logs promtail | tail -n 50`
  - Loki ready: `curl -s http://localhost:3100/ready`
  - Check auditd/inotify on Server 2: see Host monitors above

- Promtail up but no streams
  - Confirm `promtail-agent.yml` has correct `url: http://185.252.234.29:3100/loki/api/v1/push`
  - Verify labels `job` and `host` and paths `/var/log/*` and Docker logs

- High resource usage
  - Reduce Prometheus retention; stop optional profiles; shorten ES log retention; consider Loki for container/sys logs.

## Migration to Kubernetes (later)

- Keep host-level `deploy-monitor.sh` as-is
- Replace agent compose with DaemonSets (Filebeat/Promtail, Node Exporter, Falco)
- Keep hub in Docker or install kube-prometheus-stack/ELK via Helm

---
