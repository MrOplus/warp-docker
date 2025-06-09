# Cloudflare WARP SOCKS5 Proxy

A Docker container that provides a SOCKS5 proxy server routing all traffic through Cloudflare WARP. Supports both consumer WARP and Cloudflare for Teams (Zero Trust) configurations.

## 🚀 Features

- **SOCKS5 Proxy Server** on port 1080 (mapped to host port 51080)
- **Cloudflare WARP Integration** with automatic registration and connection
- **Zero Trust Support** with token-based team registration
- **Persistent Configuration** with volume mounting
- **Health Checks** to ensure WARP connectivity
- **Automatic Retry Logic** with connection failure handling

## 📋 Prerequisites

- Docker and Docker Compose
- For Teams usage: Valid Cloudflare for Teams token from your organization

## 🛠️ Installation & Usage

### Quick Start (Consumer WARP)

```bash
# Clone and start
git clone <repository>
cd wrap-cli
docker-compose up -d

# Check logs
docker-compose logs -f

# Test the proxy
curl --socks5 localhost:51080 https://ipinfo.io
```

### Teams/Zero Trust Usage

1. **Get your team token** from `https://YOUR_TEAM.cloudflareaccess.com/warp`

2. **Set the token in docker-compose.yml**:
```yaml
environment:
  - WARP_TOKEN=com.cloudflare.warp://yourteam.cloudflareaccess.com/auth?token=YOUR_JWT_TOKEN
```

3. **Start the container**:
```bash
docker-compose up -d
```

### Advanced Configuration

#### Custom WARP Version
```yaml
services:
  warp-proxy:
    build:
      args:
        - WARP_URL=https://downloads.cloudflareclient.com/v1/download/noble-intel/version/CUSTOM_VERSION
```

#### Different Port Mapping
```yaml
ports:
  - "3128:1080"  # Map to port 3128 instead
```

## 🔧 Configuration Files

### docker-compose.yml
- **Port Mapping**: `51080:1080` (host:container)
- **Environment Variables**: WARP_TOKEN for Teams usage
- **Volume Mount**: `./warp:/var/lib/cloudflare-warp` for persistent config
- **Health Checks**: Monitors WARP connection status

### start-proxy.sh
- **WARP Proxy Mode**: Configures WARP on port 40000
- **Registration Logic**: Handles both consumer and Teams registration
- **Connection Monitoring**: Retries up to 5 times on failure
- **Proxy Forwarding**: Uses Dante SOCKS5 server to forward port 1080 to WARP's port 40000

### danted.conf
- **SOCKS5 Proxy Server**: Dante server configuration
- **Internal Interface**: Listens on all interfaces (0.0.0.0) port 1080
- **External Interface**: Routes to localhost (127.0.0.1)
- **Upstream Proxy**: Forwards SOCKS5 traffic to WARP proxy on port 40000
- **Authentication**: No authentication required (socksmethod: none)
- **Protocol Support**: Both TCP and UDP traffic

### Architecture Flow
```
Client → SOCKS5 (port 1080) → Dante Proxy → WARP Proxy (port 40000) → Cloudflare Network
```

## 📊 Monitoring & Troubleshooting

### Check Status
```bash
# View logs
docker-compose logs -f warp-proxy

# Check WARP status inside container
docker exec warp-socks5-proxy warp-cli status

# Check Dante SOCKS5 proxy status
docker exec warp-socks5-proxy ps aux | grep danted

# Test connectivity
curl --socks5 localhost:51080 https://ipinfo.io
```

### Common Issues

#### Teams Registration Fails
```bash
# Error: "Failed to connect WARP after 5 attempts"
# Solution: Enable Proxy Mode in Teams Dashboard
# Go to: Settings > WARP Client > Profile > Service Mode > Proxy
```

#### Port Already in Use
```bash
# Change the host port in docker-compose.yml
ports:
  - "DIFFERENT_PORT:1080"
```

#### Connection Timeouts
```bash
# Check if your network blocks WARP traffic
# Try different network or VPN
```

#### Dante Proxy Issues
```bash
# Check Dante configuration
docker exec warp-socks5-proxy cat /etc/danted.conf

# Check Dante logs
docker exec warp-socks5-proxy tail -f /var/log/danted.log

# Restart Dante if needed
docker exec warp-socks5-proxy pkill danted
docker exec warp-socks5-proxy danted -f /etc/danted.conf -D
```

## 🔒 Security Considerations

### Current Security Issues ⚠️

1. **No Authentication on SOCKS5 Proxy**
   - Proxy accepts connections from any source (0.0.0.0/0)
   - **Risk**: Unauthorized proxy usage if exposed to internet
   - **Recommendation**: Add SOCKS5 authentication or restrict network access

2. **Dante Configuration Now Active**
   - The dante configuration file (`danted.conf`) is now actively used
   - **Note**: Implementation switched from socat to Dante SOCKS5 proxy server

### Security Best Practices

```bash
# Restrict network access to trusted IPs only
iptables -A INPUT -p tcp --dport 51080 -s TRUSTED_IP -j ACCEPT
iptables -A INPUT -p tcp --dport 51080 -j DROP
```

## 🏗️ Architecture Details

### Container Structure
- **Base Image**: Ubuntu 24.04 (for GLIBC 2.39 compatibility)
- **WARP Client**: Latest stable version (2025.4.943.0)
- **Proxy Method**: Dante SOCKS5 server forwarding to WARP's built-in proxy
- **User Management**: Separate warpuser (UID 1001) for WARP operations

### Network Flow
1. Client connects to SOCKS5 proxy (port 1080)
2. Dante SOCKS5 server forwards traffic to WARP proxy (port 40000)
3. WARP proxy routes through Cloudflare network
4. Response returns through same path

### Data Persistence
- WARP configuration stored in `./warp` directory
- Automatic registration recovery on container restart
- Health checks ensure continuous connectivity

## 🔄 Updates & Maintenance

### Update WARP Client
```bash
# Update WARP_URL in docker-compose.yml
# Rebuild container
docker-compose build --no-cache
docker-compose up -d
```

### Backup Configuration
```bash
# Backup WARP settings
cp -r ./warp ./warp-backup-$(date +%Y%m%d)
```

### Log Rotation
```yaml
# Add to docker-compose.yml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## 📝 Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `WARP_TOKEN` | Teams registration token | None | For Teams usage |
| `DEBIAN_FRONTEND` | Prevents interactive prompts | `noninteractive` | Yes |

## 🎯 Use Cases

- **Privacy Protection**: Route traffic through Cloudflare's network
- **Geo-location Bypass**: Access region-restricted content
- **Corporate Networks**: Teams integration with Zero Trust policies
- **Development Testing**: Test applications with different IP addresses
- **Network Security**: Additional layer of traffic encryption

## 📞 Support

For issues related to:
- **WARP Client**: Check Cloudflare WARP documentation
- **Teams Configuration**: Contact your Cloudflare administrator
- **Container Issues**: Check logs with `docker-compose logs -f`

## 📄 License

This project is provided as-is for educational and development purposes. Ensure compliance with Cloudflare's Terms of Service and your organization's policies.
