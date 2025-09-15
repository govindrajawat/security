#!/usr/bin/env bash
# Setup host-level monitoring (auditd, inotify, AIDE) - Run on all servers
set -e

echo "[*] Installing required packages..."
sudo apt-get update -y
sudo apt-get install -y auditd audispd-plugins aide inotify-tools

echo "[*] Configuring auditd rules..."
cat <<'EOF' | sudo tee /etc/audit/rules.d/hardening.rules
## Monitor identity files
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group  -p wa -k identity

## Watch key system logs for tampering
-w /var/log/auth.log -p wa -k authlogs
-w /var/log/syslog   -p wa -k syslogs
-w /var/log/kern.log -p wa -k kernlogs
-w /var/log/faillog  -p wa -k faillogs
-w /var/log/lastlog  -p wa -k lastlogs
## Reduce noise: ignore frequent netfilter and socket spam (allowed fields only)
-a always,exclude -F msgtype=NETFILTER_CFG
-a always,exclude -F msgtype=SOCKADDR
-a always,exclude -F msgtype=ANOM_PROMISCUOUS
EOF

sudo augenrules --load
sudo systemctl enable --now auditd

echo "[*] Creating inotify watcher..."
sudo tee /usr/local/bin/inotify-watch.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
# Inotify Watcher (security-critical paths only)
WATCH_DIRS="/etc /bin /sbin /usr/bin /usr/sbin /lib /lib64 /usr/lib /boot /root /etc/docker"
LOGFILE="/var/lib/inotify/changes.log"

inotifywait -m -r \
  -e modify,create,delete,attrib $WATCH_DIRS \
  --exclude 'changes\.log$' \
  --format '%T %w %e %f' --timefmt '%Y-%m-%d %H:%M:%S' >> $LOGFILE
EOF

sudo chmod +x /usr/local/bin/inotify-watch.sh

sudo tee /etc/systemd/system/inotify-watch.service > /dev/null <<'EOF'
[Unit]
Description=Inotify File Change Watcher
After=network.target

[Service]
ExecStart=/usr/local/bin/inotify-watch.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir -p /var/lib/inotify
sudo systemctl daemon-reload
sudo systemctl enable --now inotify-watch.service

echo "[*] Setting up AIDE configuration..."
sudo tee /etc/aide/aide.conf > /dev/null <<'EOF'
# ======================
# AIDE Configuration
# ======================

database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
database_new=file:/var/lib/aide/aide.db.new
gzip_dbout=yes

Checksums = sha256+sha512+rmd160+crc32

# Rules
NORMAL = p+i+n+u+g+s+m+c+acl+selinux+xattrs+sha512

# What to monitor (skip noisy Docker build dirs & logs)
# Critical configs
/etc    NORMAL

# System binaries
/bin    NORMAL
/sbin   NORMAL
/usr/bin    NORMAL
/usr/sbin   NORMAL

# Libraries
/lib    NORMAL
/lib64  NORMAL
/usr/lib NORMAL

# Boot & kernel
/boot   NORMAL

# Root's home
/root   NORMAL

# Docker configs (but not image/cache storage)
/etc/docker   NORMAL
EOF

echo "[*] Initializing AIDE database..."
sudo aide --config=/etc/aide/aide.conf --init
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

echo "[*] Host monitoring setup complete!"
echo " - auditd logging to /var/log/audit/audit.log"
echo " - AIDE baseline at /var/lib/aide/aide.db"
echo " - Inotify changes logged in /var/lib/inotify/changes.log"
