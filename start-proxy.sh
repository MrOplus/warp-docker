#!/bin/bash
# This script is now managed by supervisord
# All services are handled by supervisord configuration

echo "Container started with supervisord managing all services:"
echo "- WARP service (warp-svc)"
echo "- WARP setup and connection monitoring"
echo "- Dante SOCKS5 proxy server"
echo ""
echo "Check logs with: docker logs <container_name>"
echo "Or individual service logs in /var/log/supervisor/"

# Keep the container running
exec "$@"