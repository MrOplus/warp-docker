FROM ubuntu:24.04

ARG WARP_URL="https://downloads.cloudflareclient.com/v1/download/noble-intel/version/2025.4.943.0"
RUN apt update && apt install -y \
    wget \
    libdbus-1-3 \
    iproute2 \
    nftables \
    gnupg2 \
    desktop-file-utils \
    libcap2-bin \
    libnss3-tools \
    libpcap0.8 \
    sudo \
    dante-server

# Download and install cloudflare-warp
RUN wget $WARP_URL \
    -O cloudflare-warp.deb && \
    dpkg -i cloudflare-warp.deb && \
    rm cloudflare-warp.deb

# Clean up package cache
RUN apt clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user for WARP registration  
# Use UID 1001 to avoid conflicts with existing users
RUN useradd -m -s /bin/bash -u 1001 warpuser

# Create a wrapper script to run WARP commands as warpuser
RUN echo '#!/bin/bash\n\
exec su -c "$*" warpuser\n\
' > /usr/local/bin/run-as-warpuser && chmod +x /usr/local/bin/run-as-warpuser

# Copy configuration files and scripts
COPY start-proxy.sh /usr/local/bin/start-proxy.sh
COPY danted.conf /etc/danted.conf
RUN chmod +x /usr/local/bin/start-proxy.sh

# Expose SOCKS5 proxy port
EXPOSE 1080

CMD ["/usr/local/bin/start-proxy.sh"]