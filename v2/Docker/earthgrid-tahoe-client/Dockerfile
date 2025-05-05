FROM python:3.9-slim-bullseye
LABEL maintainer="Project Earthgrid Team"
LABEL description="Tahoe-LAFS Client Container for Earthgrid Storage Network"
LABEL version="1.0"

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    libffi-dev \
    libssl-dev \
    python3-dev \
    build-essential \
    git \
    curl \
    rsyslog \
    supervisor \
    fuse \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Tahoe-LAFS
RUN pip install --no-cache-dir \
    'tahoe-lafs==1.16.0' \
    'cryptography>=36.0.0' \
    'twisted>=21.0.0' \
    'pyyaml>=6.0' \
    'foolscap>=0.13.0'

# Create necessary directories
RUN mkdir -p /app /var/lib/tahoe-client /var/log/earthgrid

# Copy configuration files and scripts
COPY config/ /app/config/
COPY scripts/ /app/scripts/

# Set execute permissions on scripts
RUN chmod +x /app/scripts/*.sh

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/

# Set default parameters
ENV NODE_NAME client
ENV CLIENT_PORT 3456
ENV INTRODUCER_FURL ""
ENV SHARES_NEEDED 3
ENV SHARES_HAPPY 7
ENV SHARES_TOTAL 10
ENV NICKNAME "earthgrid-client"

# Expose Tahoe client port
EXPOSE 3456

# Use supervisor to manage services
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]