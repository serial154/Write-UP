#!/bin/bash
set -e

# Configure SSH
echo "=== Configuring SSH ==="

# Ensure SSH host keys exist (do not start init scripts to avoid duplicates)
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
	ssh-keygen -A
fi

# Set up SSH configuration for root key-based auth (optional)
mkdir -p /root/.ssh
chmod 700 /root/.ssh

echo "SSH configured"

# Start cron in background
/usr/sbin/cron || true

echo "=== Challenge environment ready ==="

# Launch sshd in foreground so the container stays running
exec /usr/sbin/sshd -D
