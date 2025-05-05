FROM debian:bullseye-slim
LABEL maintainer="Project Earthgrid Team"
LABEL description="Tinc VPN Container for Earthgrid Storage Network"
LABEL version="2.0"

# Install essential packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    tinc \
    gnupg \
    git \
    curl \
    jq \
    cron \
    gettext-base \
    iproute2 \
    iptables \
    procps \
    ca-certificates \
    python3 \
    python3-yaml \
    rsyslog \
    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /etc/tinc/earthgrid/hosts \
             /app \
             /var/lib/earthgrid/manifest \
             /var/log/earthgrid

# Set working directory
WORKDIR /app

# Copy scripts
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Copy configuration files
COPY config/ /app/config/

# Setup supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose tinc ports
EXPOSE 655/tcp 655/udp

# Use supervisor as the entrypoint to manage multiple processes
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]