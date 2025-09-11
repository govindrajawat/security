#!/usr/bin/env bash
set -e

# Bootstrap script for Server 1 (Hub)

echo "[*] Generating configs..."
./setup-configs.sh

echo "[*] Starting monitoring stack..."
docker-compose -f docker-compose.hub.yml up -d

echo "[*] Installing host-level monitors (auditd, AIDE, inotify)..."
./deploy-monitor.sh

echo "[*] Status check:"
./check-status.sh hub

echo "[*] Done. Access Kibana: http://localhost:5601, Grafana: http://localhost:3000, Prometheus: http://localhost:9090"
