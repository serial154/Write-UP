FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive 

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        cron \
        curl \
        iproute2 \
        openssh-server \
        passwd \
        nano \
        vim \
        wget \
        zip \
        tar \
        python3 \
        sudo \
    && rm -rf /var/lib/apt/lists/*

COPY src/cleanup.py /home/restadmin/cleanup.py
COPY bootstrap.sh /root/bootstrap.sh
COPY flag.txt /root/flag.txt

RUN chmod +x /root/bootstrap.sh

RUN mkdir -p /var/run/sshd

RUN printf '%s\n' '/bin/bash' '/bin/rbash' >> /etc/shells \
    && ln -sf /bin/bash /bin/rbash \
    && useradd -m -s /bin/rbash -d /home/john john \
    && useradd -m -d /home/mark mark \
    && useradd -m -d /home/restadmin restadmin \
    && chown -R john:john /home/john \
    && chown -R mark:mark /home/mark \
    && chown -R restadmin:restadmin /home/restadmin \
    && printf 'john:%s\n' "MilSecIndustries1" | chpasswd \
    && echo "john ALL=(mark) NOPASSWD: /bin/tar xf *" >> /etc/sudoers \
    && echo "mark ALL=(restadmin) NOPASSWD:SETENV: /usr/bin/python3 /home/restadmin/cleanup.py" >> /etc/sudoers \
    && chown root:root /root/flag.txt \
    && chmod 440 /root/flag.txt \
    && chown root:restadmin /bin/vim \
    && chmod 4750 /bin/vim


RUN mkdir -p /home/john/bin \
    && ln -s /usr/bin/zip /home/john/bin/zip \
    && chown -R john:john /home/john \
    && chmod 755 /home/john/bin \
    && printf '%s\n' \
        'case "$0" in' \
        '  *rbash*)' \
        '    export PATH=/home/john/bin' \
        '    command_not_found_handle() {' \
        '      echo "Commande interdite; veuillez utiliser ce bash seulement pour la commande zip"' \
        '      return 127' \
        '    }' \
        '    ;;' \
        '  *)' \
        '    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
        '    ;;' \
        'esac' \
        > /home/john/.profile \
    && cp /home/john/.profile /home/john/.bashrc \
    && chown root:root /home/john/.profile /home/john/.bashrc \
    && chmod 644 /home/john/.profile /home/john/.bashrc \
    && usermod -s /bin/rbash john

EXPOSE 22
ENTRYPOINT ["/bin/bash", "/root/bootstrap.sh"]
