#!/usr/bin/env bash
# Agent Setup for Servers 2-7
set -e

SERVER1_IP="${SERVER1_IP:-185.252.234.29}"  # Hub (Server 1) IP (can override via env)

echo "[*] Creating agent configuration..."
mkdir -p fail2ban-agent/jail.d
mkdir -p tmp

# Filebeat config for agent servers
cat > filebeat-agent.yml <<EOF
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/audit/audit.log
  fields:
    log_type: audit
    server: "$(hostname -f)"
  fields_under_root: true

- type: log
  enabled: true
  paths:
    - /var/log/inotify-changes.log
  fields:
    log_type: inotify
    server: "$(hostname -f)"
  fields_under_root: true

- type: log
  enabled: true
  paths:
    - /var/log/syslog
    - /var/log/auth.log
  fields:
    log_type: system
    server: "$(hostname -f)"
  fields_under_root: true

- type: container
  paths:
    - '/var/lib/docker/containers/*/*.log'
  fields:
    server: "$(hostname -f)"
  fields_under_root: true

output.logstash:
  hosts: ["${SERVER1_IP}:5044"]

processors:
- add_host_metadata:
    when.not.contains.tags: forwarded
- add_docker_metadata: ~
EOF

# Simple Fail2Ban config for agents
cat > fail2ban-agent/jail.d/agent.conf <<'EOF'
[DEFAULT]
bantime = 1800
findtime = 300
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
EOF

echo "[*] Agent configuration created!"
echo "Run: docker-compose -f docker-compose.agent.yml up -d"

echo "[*] Creating Promtail configuration..."
cat > promtail-agent.yml <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://${SERVER1_IP}:3100/loki/api/v1/push

scrape_configs:
  - job_name: system-logs
    static_configs:
      - targets: [localhost]
        labels:
          job: varlogs
          host: $(hostname -f)
          __path__: /var/log/{auth.log,syslog}

  - job_name: docker-containers
    static_configs:
      - targets: [localhost]
        labels:
          job: containers
          host: $(hostname -f)
          __path__: /var/lib/docker/containers/*/*.log
    pipeline_stages:
      - docker: {}

  - job_name: security
    static_configs:
      - targets: [localhost]
        labels:
          job: security
          host: $(hostname -f)
          __path__: /var/log/inotify-changes.log
EOF

echo "[*] Promtail configuration created at promtail-agent.yml"