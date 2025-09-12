#!/usr/bin/env bash
# Start Server 2-7 (Agent) - Log forwarding and metrics
set -e

SERVER1_IP=${1:-"185.252.234.29"}

echo "[*] Starting Agent for Server 1: $SERVER1_IP"

# Create required directories
sudo mkdir -p /var/lib/inotify

# Update Promtail config with correct server IP
sed -i "s/185.252.234.29/$SERVER1_IP/g" promtail/promtail-agent.yml

# Start agent services
docker compose -f docker-compose.agent.yml up -d

echo "[*] Agent services started!"
echo "Logs forwarded to: $SERVER1_IP:3100"

# Health check
./check-status.sh agent
