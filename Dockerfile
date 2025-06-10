FROM ubuntu:24.04

RUN apt update && apt install -y \
    curl \
    iproute2 \
    nftables \
    gnupg2 \
    desktop-file-utils \
    libcap2-bin \
    libnss3-tools \
    libpcap0.8 \
    sudo \
    dante-server \
    supervisor \
    lsb-release

# Add Cloudflare GPG key and repository
RUN curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list

# Install cloudflare-warp from official repository
RUN apt update && apt install -y cloudflare-warp

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
COPY warp-setup.sh /usr/local/bin/warp-setup.sh
COPY danted.conf /etc/danted.conf
COPY supervisord.conf /etc/supervisord.conf
RUN chmod +x /usr/local/bin/warp-setup.sh

# Create supervisor log directory
RUN mkdir -p /var/log/supervisor

# Expose SOCKS5 proxy port
EXPOSE 1080

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]