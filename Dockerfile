FROM debian:bookworm-slim

ARG SSH_PORT=2222

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        openssh-server \
        tmux \
        curl \
        wget \
        git \
        vim \
        ca-certificates \
        procps \
        lsof \
        net-tools \
        locales \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i "s/#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config \
    && mkdir -p /run/sshd

RUN echo "root:debian123" | chpasswd

RUN useradd -m -s /bin/bash vm \
    && echo "vm:vm123" | chpasswd \
    && usermod -aG sudo vm

EXPOSE ${SSH_PORT}

ENTRYPOINT ["/usr/sbin/sshd", "-D"]
