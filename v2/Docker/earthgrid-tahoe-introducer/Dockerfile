FROM python:3.9-slim-bullseye
LABEL maintainer="Project Earthgrid Team"
LABEL description="Tahoe-LAFS Introducer Container for Earthgrid Storage Network"
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
RUN mkdir -p /app /var/lib/tahoe-introducer /var/log/earthgrid

# Copy configuration files and scripts
COPY config/ /app/config/
COPY scripts/ /app/scripts/

# Set execute permissions on scripts
RUN chmod +x /app/scripts/*.sh

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/

# Set default parameters
ENV NODE_NAME introducer
ENV INTRODUCER_PORT 3458
ENV NICKNAME "earthgrid-introducer"

# Expose Tahoe introducer port
EXPOSE 3458

# Use supervisor to manage services
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]