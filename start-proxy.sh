#!/bin/bash
# Start D-Bus service
echo "Starting D-Bus service..."
service dbus start

# Start WARP daemon as root (required for network operations)
echo "Starting Cloudflare WARP daemon..."
warp-svc > /dev/null 2>&1 &
sleep 5
# Configure Warp Proxy
echo "Configuring WARP Proxy..."
sudo -u warpuser warp-cli --accept-tos proxy port 40000
echo "Setting WARP Proxy mode..."
sudo -u warpuser warp-cli --accept-tos mode proxy
echo "WARP Proxy configured on port 40000."
echo "Checking WARP registration status..."
show=$(sudo -u warpuser warp-cli --accept-tos registration show 2>&1)
# check if "warp-cli registration new" is in the output
if [[ $show == *"warp-cli registration new"* ]]; then
    # check if WARP_TOKEN is set , if not register as normal user
    if [ -z "$WARP_TOKEN" ]; then
        echo "====================================="
        echo "No WARP_TOKEN found, registering as normal user..."
        echo "If you want to register with a token, set the WARP_TOKEN environment variable."
        echo "You can get a token by opening https://TEAM_NAME.cloudflareaccess.com/warp"        
        echo "====================================="
        sudo -u warpuser warp-cli --accept-tos registration new
    else
        echo "No registration found, initializing registration..."
        TEAM_NAME=$(echo "$WARP_TOKEN" | grep -oP '(?<=//)[^/]+')
        TEAM_NAME=${TEAM_NAME%%.*}  # Remove everything after the first dot        
        echo "====================================="
        echo "No WARP registration found, registering with team name: $TEAM_NAME"
        echo "If you want to register without a team, unset the WARP_TOKEN environment variable."
        echo "====================================="
        sudo -u warpuser warp-cli --accept-tos registration new "$TEAM_NAME"
        sudo -u warpuser warp-cli --accept-tos registration initialize-token-callback
        sudo -u warpuser warp-cli --accept-tos registration token "$WARP_TOKEN"
    fi
fi

# show the current registration status
echo "Current registration status:"
warp-cli --accept-tos registration show
warp-cli --accept-tos connect
# loop to check if WARP is connected
failures=0
while true; do
    status=$(warp-cli --accept-tos status)
    if [[ $status == *"Connected"* ]]; then
        echo "WARP is connected."
        break
    else
        echo "WARP is not connected, retrying in 5 seconds..."
        failures=$((failures + 1))
        if [ $failures -ge 5 ]; then
            echo "Failed to connect WARP after 5 attempts. Exiting..."
            echo "If you are using TEAM make sure that you have enabled PROXY Mode in the WARP Profile Dashboard!"
            echo "Settings > Warp Client > Profile > Service Mode > Proxy"
            echo "Suggestion: Create new Profile based on user or os (linux) and enable Proxy Mode."
            exit 1
        fi
        sleep 5
    fi
done

# Start the proxy server

echo "Starting Dante SOCKS5 proxy server..."
danted -f /etc/danted.conf