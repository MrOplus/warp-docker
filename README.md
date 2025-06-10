# Cloudflare WARP SOCKS5 Proxy (Proxy Mode Only)

A Docker container that provides a SOCKS5 proxy server routing traffic through Cloudflare WARP in **proxy mode only**. This implementation does not support full VPN mode - it only works as a SOCKS5 proxy. Supports both consumer WARP and Cloudflare for Teams (Zero Trust) configurations.

## 🚀 Features

- **SOCKS5 Proxy Server** on port 1080 (mapped to host port 51080)
- **Proxy Mode Only** - Routes traffic through WARP proxy, not full VPN tunnel
- **Cloudflare WARP Integration** with automatic registration and connection
- **Zero Trust Support** with token-based team registration
- **Persistent Configuration** with volume mounting
- **Health Checks** to ensure WARP connectivity
- **Automatic Retry Logic** with connection failure handling

## 📋 Prerequisites

- Docker and Docker Compose
- For Teams usage: Valid Cloudflare for Teams token from your organization
- **Important**: For Teams usage, ensure "Proxy Mode" is enabled in your WARP profile settings

## ⚠️ Important Limitations

### Proxy Mode Only
This container **only supports WARP proxy mode**, not full VPN mode. This means:

- **✅ SOCKS5 Proxy**: Applications must be configured to use the SOCKS5 proxy
- **❌ System-wide VPN**: Does not route all system traffic automatically  
- **✅ Application-specific**: Only traffic routed through the proxy is affected
- **❌ Transparent Proxy**: Cannot intercept traffic without explicit proxy configuration

### Teams Requirements
For Cloudflare for Teams usage:
- Your organization must have **Proxy Mode enabled** in WARP profile settings
- Navigate to: `Settings > WARP Client > Profile > Service Mode > Proxy`
- Create a profile specifically for proxy mode if needed

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

### supervisord.conf
- **Process Management**: Manages all services with proper dependencies
- **Service Monitoring**: Automatic restart of failed services
- **Logging**: Individual log files for each service in `/var/log/supervisor/`
- **Services Managed**: WARP daemon, WARP setup, Dante proxy (D-Bus not required for proxy mode)

### warp-setup.sh
- **WARP Configuration**: Configures WARP on port 40000 in proxy mode
- **Registration Logic**: Handles both consumer and Teams registration
- **Connection Monitoring**: Continuous monitoring and reconnection logic
- **Health Checks**: Ensures WARP stays connected

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
# View all container logs
docker-compose logs -f warp-proxy

# Check supervisord status
docker exec warp-socks5-proxy supervisorctl status

# Check individual service logs
docker exec warp-socks5-proxy tail -f /var/log/supervisor/warp-setup.log
docker exec warp-socks5-proxy tail -f /var/log/supervisor/dante.log
docker exec warp-socks5-proxy tail -f /var/log/supervisor/warp-svc.log

# Check WARP status inside container
docker exec warp-socks5-proxy warp-cli status

# Restart specific service if needed
docker exec warp-socks5-proxy supervisorctl restart dante
docker exec warp-socks5-proxy supervisorctl restart warp-setup

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

## 🎯 Use Cases (Proxy Mode Only)

- **Application-Specific Routing**: Route specific applications through Cloudflare's network
- **Development Testing**: Test applications with different IP addresses via proxy
- **API/Web Scraping**: Route HTTP/HTTPS requests through WARP proxy
- **Corporate Applications**: Teams integration with Zero Trust policies for specific apps
- **Selective Privacy**: Choose which traffic goes through Cloudflare (not system-wide)
- **Container Networking**: Route containerized applications through WARP

**Note**: This is not a system-wide VPN - only applications configured to use the SOCKS5 proxy will be routed through WARP.

## 📞 Support

For issues related to:
- **WARP Client**: Check Cloudflare WARP documentation
- **Teams Configuration**: Contact your Cloudflare administrator
- **Container Issues**: Check logs with `docker-compose logs -f`

## 📄 License

This project is provided as-is for educational and development purposes. Ensure compliance with Cloudflare's Terms of Service and your organization's policies.
