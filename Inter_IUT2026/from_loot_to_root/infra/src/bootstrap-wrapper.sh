#!/bin/bash
set -euo pipefail

ENTRYPOINT_SCRIPT=${WINGFTP_BOOTSTRAP_DIR:-/root/wingftpd-bootstrap}/entrypoint.sh

cleanup() {
	for pid in ${SSH_PID:-} ${WF_PID:-}; do
		if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
			kill "$pid" 2>/dev/null || true
		fi
	done
}

trap cleanup INT TERM

# Required by OpenSSH on Debian/Ubuntu images
mkdir -p /run/sshd

# Start SSH daemon in background
/usr/sbin/sshd -D &
SSH_PID=$!

# Start WingFTP via entrypoint
/bin/bash "$ENTRYPOINT_SCRIPT" &
WF_PID=$!

# Cleanup bootstrap files after initialization
rm -f /opt/wordlist.txt 2>/dev/null || true

# Wait for first failure/exit, then stop the other service.
wait -n "$WF_PID" "$SSH_PID"
status=$?

cleanup
wait "$WF_PID" "$SSH_PID" 2>/dev/null || true

exit "$status"
