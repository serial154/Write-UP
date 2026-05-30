FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    WINGFTPD=/opt/wingftpd \
    WINGFTP_BOOTSTRAP_DIR=/root/wingftpd-bootstrap \
    WINGFTP_ANON_DIR=/opt/wingftpd/ftp/anonymous

# Install only runtime dependencies (no editors/dev tools).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        cron \
        curl \
        iproute2 \
        openssh-server \
        passwd \
        nano \
        vim \
        wget \
    && rm -rf /var/lib/apt/lists/*

# WingFTP payload + bootstrap files are embedded in the image.
COPY src/entrypoint.sh /root/wingftpd-bootstrap/entrypoint.sh
COPY src/bootstrap.lua /root/wingftpd-bootstrap/bootstrap.lua
COPY src/admins.xml.tpl /root/wingftpd-bootstrap/admins.xml.tpl
COPY src/admin-settings.xml.tpl /root/wingftpd-bootstrap/admin-settings.xml.tpl
COPY src/backup.env /root/wingftpd-bootstrap/backup.env
COPY src/wordlist.txt /opt/wordlist.txt
COPY user.txt /home/max/user.txt
COPY root.txt /root/root.txt

RUN useradd --system --no-create-home --shell /usr/sbin/nologin ftpsvc \
    && useradd -m max \
    && mkdir -p \
        "$WINGFTPD" \
        /var/log/wingftpd \
        "$WINGFTP_BOOTSTRAP_DIR" \
        "$WINGFTP_ANON_DIR" \
        /home/max/.ssh \
        /opt/backup \
        /run/sshd \
    && wget https://download.fileeagle.com/files/2025/05/wftpserver-linux-64bit.tar.gz -O /tmp/wftpserver-linux-64bit.tar.gz \
    && [ -s /tmp/wftpserver-linux-64bit.tar.gz ] \
    && tar -xzf /tmp/wftpserver-linux-64bit.tar.gz -C "$WINGFTPD" --strip-components=1 \
    && rm -f /tmp/wftpserver-linux-64bit.tar.gz \
    && cp "$WINGFTP_BOOTSTRAP_DIR/backup.env" "$WINGFTP_ANON_DIR/backup.env" \
    && chown ftpsvc:ftpsvc "$WINGFTP_ANON_DIR/backup.env" \
    && chmod 0644 "$WINGFTP_ANON_DIR/backup.env" \
    && chown max:max /home/max \
    && chown -R max:max /home/max/.ssh \
    && chmod 755 /home/max \
    && chmod 700 /home/max/.ssh \
    && chown -R ftpsvc:ftpsvc "$WINGFTPD" /var/log/wingftpd "$WINGFTP_BOOTSTRAP_DIR" "$WINGFTP_ANON_DIR" /opt/backup \
    && chmod +x /root/wingftpd-bootstrap/entrypoint.sh \
    && mkdir -p /opt/rclone \
    && wget https://github.com/rclone/rclone/releases/download/v1.68.1/rclone-v1.68.1-linux-amd64.deb -O /tmp/rclone.deb \
    && dpkg-deb -x /tmp/rclone.deb /opt/rclone \
    && install -o root -g root -m 0755 /opt/rclone/usr/bin/rclone /opt/rclone/rclone \
    && rm -f /tmp/rclone.deb \
    && mkdir -p /var/spool/cron/crontabs \
    && printf '%s\n' '* * * * * /opt/rclone/rclone copy /home/max /backup --links --metadata 2>&1' > /var/spool/cron/crontabs/root \
    && chmod 0600 /var/spool/cron/crontabs/root \
    && (chown root:crontab /var/spool/cron/crontabs/root 2>/dev/null || chown root:root /var/spool/cron/crontabs/root) \
    && sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && chown root:max /home/max/user.txt \
    && chmod 440 /home/max/user.txt \
    && chown root:root /root/root.txt \
    && chmod 440 /root/root.txt

RUN cat > /root/bootstrap.sh <<'WRAPPER_EOF' && chmod +x /root/bootstrap.sh
#!/bin/bash
set -e

mkdir -p /run/sshd
/usr/sbin/sshd -D &
SSH_PID=$!

/bin/bash /root/wingftpd-bootstrap/entrypoint.sh &
WF_PID=$!

wait $WF_PID $SSH_PID 2>/dev/null || true
WRAPPER_EOF

EXPOSE 21 22 5466
ENTRYPOINT ["/bin/bash", "/root/bootstrap.sh"]
