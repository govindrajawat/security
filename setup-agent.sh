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