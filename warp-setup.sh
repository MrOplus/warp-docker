#!/bin/bash

# Wait for warp-svc to be ready
echo "Waiting for WARP service to be ready..."
sleep 5

# Wait for warp-svc to actually be listening
echo "Checking if warp-svc is responding..."
for i in {1..15}; do
    if warp-cli --accept-tos status >/dev/null 2>&1; then
        echo "WARP service is responding."
        break
    fi
    echo "Waiting for WARP service... ($i/15)"
    sleep 2
done

# Configure WARP Proxy
echo "Configuring WARP Proxy..."
sudo -u warpuser warp-cli --accept-tos proxy port 40000
echo "Setting WARP Proxy mode..."
sudo -u warpuser warp-cli --accept-tos mode proxy
echo "WARP Proxy configured on port 40000."

echo "Checking WARP registration status..."
show=$(sudo -u warpuser warp-cli --accept-tos registration show 2>&1)

# Check if "warp-cli registration new" is in the output
if [[ $show == *"warp-cli registration new"* ]]; then
    # Check if WARP_TOKEN is set, if not register as normal user
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

# Show the current registration status
echo "Current registration status:"
warp-cli --accept-tos registration show
warp-cli --accept-tos connect

# Loop to check if WARP is connected
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

echo "WARP setup completed successfully. Monitoring connection..."

# Keep the script running to monitor WARP connection
while true; do
    sleep 30
    status=$(warp-cli --accept-tos status 2>/dev/null)
    if [[ $status != *"Connected"* ]]; then
        echo "WARP connection lost. Attempting to reconnect..."
        warp-cli --accept-tos connect
    fi
done
