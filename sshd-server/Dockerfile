FROM ubuntu:22.04

# Install OpenSSH Server and create user
RUN apt-get update && apt-get install -y openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash sshuser \
    && mkdir -p /home/sshuser/.ssh && chmod 700 /home/sshuser/.ssh

# Copy custom sshd_config and principals file
COPY sshd_config /etc/ssh/sshd_config
COPY authorized_principals /etc/ssh/authorized_principals

# Create directory for the CA public key
RUN mkdir -p /etc/ssh/ca

# Expose port and start sshd
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]