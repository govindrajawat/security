#!/usr/bin/env bash
# Start Server 1 (Hub) - All monitoring services
set -e

echo "[*] Starting Security Stack Hub..."

# Create required directories
mkdir -p /var/lib/inotify

# Start all services
docker compose -f docker-compose.hub.yml up -d

echo "[*] Hub services started!"
echo "Access:"
echo "  Grafana: http://localhost:3000 (admin/admin123)"
echo "  Prometheus: http://localhost:9090"
echo "  Loki: http://localhost:3100"

# Health check
./check-status.sh hub
