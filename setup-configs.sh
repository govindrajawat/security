#!/usr/bin/env bash
# Configuration Setup Script for Server 1
set -e

echo "[*] Creating configuration directories..."
mkdir -p prometheus
mkdir -p alertmanager
mkdir -p logstash/config
mkdir -p filebeat
mkdir -p fail2ban/jail.d
mkdir -p falco

echo "[*] Creating Prometheus configuration..."
cat > prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporters'
    static_configs:
      - targets: 
        - '185.252.234.29:9100'
        - '84.46.255.10:9100'
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'go_.+|process_.+'
        action: drop
EOF

echo "[*] Creating Prometheus alert rules..."
cat > prometheus/alert_rules.yml <<'EOF'
groups:
- name: system
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ \$labels.instance }}"

  - alert: HighMemoryUsage
    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on {{ \$labels.instance }}"

  - alert: DiskSpaceLow
    expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 20
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Low disk space on {{ \$labels.instance }}"
EOF

echo "[*] Creating Alertmanager configuration..."
cat > alertmanager/alertmanager.yml <<'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  webhook_configs:
  - url: 'http://prometheus:9090/-/reload'
EOF

echo "[*] Creating Logstash configuration..."
cat > logstash/config/logstash.conf <<'EOF'
input {
  beats {
    port => 5044
  }
  syslog {
    port => 5000
  }
}

filter {
  if [fields][log_type] == "audit" {
    grok {
      match => { "message" => "%{GREEDYDATA:audit_message}" }
    }
  }
  
  if [fields][log_type] == "inotify" {
    grok {
      match => { 
        "message" => "%{TIMESTAMP_ISO8601:timestamp} %{DATA:path} %{DATA:event} %{GREEDYDATA:filename}" 
      }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logs-%{+YYYY.MM.dd}"
    ilm_enabled => false
  }
  stdout { codec => json }
}
EOF

echo "[*] Creating Filebeat configuration..."
cat > filebeat/filebeat.yml <<'EOF'
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/audit/audit.log
  fields:
    log_type: audit
    server: "hub-185.252.234.29"
  fields_under_root: true

- type: log
  enabled: true
  paths:
    - /var/log/inotify-changes.log
  fields:
    log_type: inotify
    server: "hub-185.252.234.29"
  fields_under_root: true

- type: log
  enabled: true
  paths:
    - /var/log/syslog
    - /var/log/auth.log
  fields:
    log_type: system
    server: "hub-185.252.234.29"
  fields_under_root: true

- type: container
  paths:
    - '/var/lib/docker/containers/*/*.log'
  fields:
    server: "hub-185.252.234.29"
  fields_under_root: true

output.logstash:
  hosts: ["logstash:5044"]

processors:
- add_host_metadata:
    when.not.contains.tags: forwarded
- add_docker_metadata: ~
EOF

echo "[*] Creating Fail2Ban jail configuration..."
cat > fail2ban/jail.d/custom.conf <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = auto

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3

[docker-auth]
enabled = true
filter = docker-auth
logpath = /var/log/daemon.log
maxretry = 3
EOF

echo "[*] Creating Falco rules..."
cat > falco/falco_rules.local.yaml <<'EOF'
- rule: Docker Container Spawned
  desc: A docker container was spawned
  condition: >
    spawned_process and container
  output: >
    Container started (user=%user.name command=%proc.cmdline container_id=%container.id 
    container_name=%container.name image=%container.image.repository)
  priority: INFO
  tags: [container, docker]

- rule: File Created in Sensitive Directory
  desc: File created in sensitive system directory
  condition: >
    fd.name startswith /etc or fd.name startswith /bin or fd.name startswith /sbin
  output: >
    File created in sensitive dir (user=%user.name command=%proc.cmdline 
    file=%fd.name container=%container.name)
  priority: WARNING
  tags: [filesystem, security]
EOF

echo "[*] Configuration files created successfully!"
echo "Run: docker-compose -f docker-compose.monitoring.yml up -d"