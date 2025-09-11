#!/usr/bin/env bash
# System Status Check Script
set -e

SERVER_TYPE=${1:-""}

if [[ "$SERVER_TYPE" == "hub" ]]; then
    echo "=== HUB SERVER STATUS (185.252.234.29) ==="
    echo ""
    
    echo "[*] Docker Services Status:"
    docker-compose -f docker-compose.monitoring.yml ps
    echo ""
    
    echo "[*] Service Health Checks:"
    services=("elasticsearch:9200" "kibana:5601" "prometheus:9090" "grafana:3000" "vault:8200")
    
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
    
    echo "[*] Log Indices (last 3 days):"
    curl -s http://localhost:9200/_cat/indices/logs-* | tail -3
    echo ""
    
    echo "[*] System Resources:"
    echo "Memory: $(free -h | awk 'NR==2{printf "%.1fGB/%.1fGB (%.0f%%)\n", $3/1024, $2/1024, $3*100/$2}')"
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
    docker-compose -f docker-compose.agent.yml ps
    echo ""
    
    echo "[*] Service Health Checks:"
    if curl -s http://localhost:9100/metrics | head -1 >/dev/null 2>&1; then
        echo "✓ node-exporter (port 9100) - OK"
    else
        echo "✗ node-exporter (port 9100) - FAILED"
    fi
    echo ""
    
    echo "[*] Connectivity to Hub:"
    if nc -z 185.252.234.29 5044 >/dev/null 2>&1; then
        echo "✓ Logstash (185.252.234.29:5044) - OK"
    else
        echo "✗ Logstash (185.252.234.29:5044) - FAILED"
    fi
    echo ""
    
    echo "[*] System Resources:"
    echo "Memory: $(free -h | awk 'NR==2{printf "%.1fGB/%.1fGB (%.0f%%)\n", $3/1024, $2/1024, $3*100/$2}')"
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