FROM debian:bullseye-slim
LABEL maintainer="Ptlug"
LABEL description="Tinc VPN Container for Earthgrid Storage Netowork"
LABEL version="1.0"

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
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/tinc/earthgrid/hosts /app /var/lib/earthgrid
WORKDIR /app

COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

EXPOSE 655/tcp 655/udp

ENTRYPOINT ["/app/scripts/entrypoint.sh"]