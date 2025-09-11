#!/usr/bin/env bash
# System Status Check Script
set -e

SERVER_TYPE=${1:-""}

if [[ "$SERVER_TYPE" == "hub" ]]; then
    echo "=== HUB SERVER STATUS (185.252.234.29) ==="
    echo ""
    
    echo "[*] Docker Services Status:"
    docker compose -f docker-compose.hub.yml ps
    echo ""
    
    echo "[*] Service Health Checks:"
    services=("loki:3100" "prometheus:9090" "grafana:3000")
    
    for service in "${services[@]}"; do
        name=${service%:*}
        port=${service#*:}
        if curl -s http://localhost:$port >/dev/null 2>&1; then
            echo "✓ $name (port $port) - OK"
        else
            echo "✗ $name (port $port) - FAILED"
        fi
    done
    echo ""
    
    echo "[*] Monitoring Targets:"
    targets_status=$(curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"[^"]*"' | sort | uniq -c || echo "Unable to fetch targets")
    echo "$targets_status"
    echo ""
    
    echo "[*] Loki label values (job):"
    curl -s "http://localhost:3100/loki/api/v1/label/job/values" | jq -r '.data[]' || echo "Unable to fetch Loki labels"
    echo ""
    
    echo "[*] System Resources:"
    echo "Memory: $(free -m | awk 'NR==2{printf "%dMB/%dMB (%d%%)\n", $3, $2, ($3*100)/$2}')"
    echo "Disk: $(df -h / | awk 'NR==2{printf "%s/%s (%s)\n", $3, $2, $5}')"
    echo ""
    
    echo "[*] Security Services:"
    systemctl is-active auditd || echo "auditd: inactive"
    systemctl is-active inotify-watch || echo "inotify-watch: inactive"
    echo ""

elif [[ "$SERVER_TYPE" == "agent" ]]; then
    echo "=== AGENT SERVER STATUS (84.46.255.10) ==="
    echo ""
    
    echo "[*] Docker Services Status:"
    docker compose -f docker-compose.agent.yml ps
    echo ""
    
    echo "[*] Service Health Checks:"
    if curl -s http://localhost:9100/metrics | head -1 >/dev/null 2>&1; then
        echo "✓ node-exporter (port 9100) - OK"
    else
        echo "✗ node-exporter (port 9100) - FAILED"
    fi
    echo ""
    
    echo "[*] Connectivity to Hub (Loki):"
    if curl -s http://185.252.234.29:3100/ready >/dev/null 2>&1; then
        echo "✓ Loki (185.252.234.29:3100) - OK"
    else
        echo "✗ Loki (185.252.234.29:3100) - FAILED"
    fi
    echo ""
    
    echo "[*] System Resources:"
    echo "Memory: $(free -m | awk 'NR==2{printf "%dMB/%dMB (%d%%)\n", $3, $2, ($3*100)/$2}')"
    echo "Disk: $(df -h / | awk 'NR==2{printf "%s/%s (%s)\n", $3, $2, $5}')"
    echo ""
    
    echo "[*] Security Services:"
    systemctl is-active auditd || echo "auditd: inactive"
    systemctl is-active inotify-watch || echo "inotify-watch: inactive"
    echo ""

else
    echo "Usage: $0 [hub|agent]"
    echo ""
    echo "Run on Server 1: $0 hub"
    echo "Run on Server 2: $0 agent"
fi