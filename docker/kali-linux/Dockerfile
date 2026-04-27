FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

# Update and install metapackage
RUN apt-get update && apt-get install -y \
    kali-linux-headless \
    # Extra network tools not in headless
    iperf3 \
    tshark \
    bridge-utils \
    net-tools \
    ethtool \
    openssh-server \
    tmux \
    iputils-ping \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Python extras
RUN pip3 install --break-system-packages \
    impacket \
    pwntools \
    netaddr \
    pyshark

# SSH setup
RUN mkdir -p /var/run/sshd \
    && echo 'root:kali' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
CMD ["/entrypoint.sh"]