#!/bin/bash
set -euo pipefail

: "${WINGFTPD:?WINGFTPD is required}"
: "${WINGFTP_BOOTSTRAP_DIR:?WINGFTP_BOOTSTRAP_DIR is required}"
: "${WINGFTP_ADMIN_USER:?WINGFTP_ADMIN_USER is required}"
: "${WINGFTP_ADMIN_PASSWORD:?WINGFTP_ADMIN_PASSWORD is required}"
: "${WINGFTP_ADMIN_PORT:?WINGFTP_ADMIN_PORT is required}"
: "${WINGFTP_BOOTSTRAP_DOMAIN_ENABLED:=1}"
: "${WINGFTP_BOOTSTRAP_DOMAIN:=lab}"
: "${WINGFTP_ANON_DIR:=/opt/wingftpd/ftp/anonymous}"

readonly PID_WAIT_RETRIES=30
readonly ADMIN_READY_RETRIES=30
readonly BOOTSTRAP_RETRIES=5

if [ "${#WINGFTP_ADMIN_PASSWORD}" -lt 8 ]; then
  echo "WINGFTP_ADMIN_PASSWORD must have at least 8 characters" >&2
  exit 1
fi

escape_sed() {
  printf '%s' "$1" | sed 's/[|&]/\\&/g'
}

regenerate_max_credentials() {
  if [ ! -f /opt/wordlist.txt ]; then
    echo "/opt/wordlist.txt is required to regenerate max credentials" >&2
    exit 1
  fi

  max_password=$(shuf -n 1 /opt/wordlist.txt)
  if [ -z "$max_password" ]; then
    echo "Failed to generate a password for max" >&2
    exit 1
  fi

  printf 'max:%s\n' "$max_password" | chpasswd

  rm -f /opt/backup/id_rsa /opt/backup/id_rsa.pub
  ssh-keygen -q -t rsa -f /opt/backup/id_rsa -N "$max_password" -C "max@milsec"
  cp /opt/backup/id_rsa.pub /home/max/.ssh/authorized_keys

  chown max:max /home/max /home/max/.ssh /home/max/.ssh/authorized_keys
  chmod 755 /home/max
  chmod 700 /home/max/.ssh
  chmod 600 /home/max/.ssh/authorized_keys
  chown ftpsvc:ftpsvc /opt/backup/id_rsa /opt/backup/id_rsa.pub
  chmod 600 /opt/backup/id_rsa
  chmod 644 /opt/backup/id_rsa.pub
}

cd "$WINGFTPD"

wingftp_dirs=(Data Data/_ADMINISTRATOR session session_admin Log/Admin /var/log/wingftpd "$WINGFTP_ANON_DIR")
mkdir -p "${wingftp_dirs[@]}"
chown -R ftpsvc:ftpsvc Data session session_admin Log /var/log/wingftpd "$WINGFTP_ANON_DIR"
chmod -R u+rwX Data session session_admin Log /var/log/wingftpd "$WINGFTP_ANON_DIR"

if [ ! -x "$WINGFTPD/wftpserver" ]; then
  echo "WingFTP binary not found or not executable: $WINGFTPD/wftpserver" >&2
  exit 1
fi

if [ -f "$WINGFTP_BOOTSTRAP_DIR/backup.env" ]; then
  cp "$WINGFTP_BOOTSTRAP_DIR/backup.env" "$WINGFTP_ANON_DIR/backup.env"
  chown ftpsvc:ftpsvc "$WINGFTP_ANON_DIR/backup.env"
  chmod 0644 "$WINGFTP_ANON_DIR/backup.env"
fi

regenerate_max_credentials

admin_hash=$(printf '%s' "${WINGFTP_ADMIN_PASSWORD}WingFTP" | sha256sum | awk '{print $1}')
admin_user_escaped=$(escape_sed "$WINGFTP_ADMIN_USER")
admin_hash_escaped=$(escape_sed "$admin_hash")
admin_port_escaped=$(escape_sed "$WINGFTP_ADMIN_PORT")

sed \
  -e "s|__ADMIN_USER__|${admin_user_escaped}|g" \
  -e "s|__ADMIN_HASH__|${admin_hash_escaped}|g" \
  "$WINGFTP_BOOTSTRAP_DIR/admins.xml.tpl" > Data/_ADMINISTRATOR/admins.xml

sed \
  -e "s|__ADMIN_PORT__|${admin_port_escaped}|g" \
  "$WINGFTP_BOOTSTRAP_DIR/admin-settings.xml.tpl" > Data/_ADMINISTRATOR/settings.xml

chown -R ftpsvc:ftpsvc Data

su -s /bin/bash ftpsvc -c "cd '$WINGFTPD' && ./wftpserver"

pid_file="$WINGFTPD/pid-wftpserver.pid"
for ((i=1; i<=PID_WAIT_RETRIES; i++)); do
  [ -s "$pid_file" ] && break
  sleep 1
done
if [ ! -s "$pid_file" ]; then
  echo "WingFTP did not create PID file" >&2
  exit 1
fi
read -r pid < "$pid_file"

# Start cron early so scheduled jobs run while WingFTP is alive.
/usr/sbin/cron || true

if [ "$WINGFTP_BOOTSTRAP_DOMAIN_ENABLED" = "1" ] && [ -n "$WINGFTP_BOOTSTRAP_DOMAIN" ]; then
  for ((i=1; i<=ADMIN_READY_RETRIES; i++)); do
    if curl -fsS "http://127.0.0.1:${WINGFTP_ADMIN_PORT}/admin_login.html" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if [ -f "$WINGFTP_BOOTSTRAP_DIR/bootstrap.lua" ]; then
    bootstrap_ok=0
    for ((i=1; i<=BOOTSTRAP_RETRIES; i++)); do
      if cd "$WINGFTPD" && ./wftpconsole -u "$WINGFTP_ADMIN_USER" -p "$WINGFTP_ADMIN_PASSWORD" -h 127.0.0.1 -P "$WINGFTP_ADMIN_PORT" -f "$WINGFTP_BOOTSTRAP_DIR/bootstrap.lua"; then
        bootstrap_ok=1
        break
      fi
      sleep 2
    done
    if [ "$bootstrap_ok" -ne 1 ]; then
      echo "WingFTP domain bootstrap failed after retries" >&2
    fi
  else
    echo "bootstrap.lua not found in $WINGFTP_BOOTSTRAP_DIR" >&2
  fi
fi

while kill -0 "$pid" 2>/dev/null; do
  sleep 2
done

echo "WingFTP process exited" >&2

exit 1
