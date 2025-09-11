#!/usr/bin/env bash
set -e

# Bootstrap script for Server 2 (Agent)

if [ -z "$SERVER1_IP" ]; then
  SERVER1_IP=185.252.234.29
fi

echo "[*] Generating agent configs (Logstash: $SERVER1_IP:5044)..."
./setup-agent.sh

echo "[*] Starting agent stack..."
docker compose -f docker-compose.agent.yml up -d

echo "[*] Status check:"
./check-status.sh agent

echo "[*] Done. Node exporter on :9100; logs forwarded to $SERVER1_IP:5044"
