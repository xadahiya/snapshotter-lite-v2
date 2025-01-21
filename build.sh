#!/bin/bash

# Run configuration
source ./configure-environment.sh "$@"
if [ $? -ne 0 ]; then
    echo "❌ Configuration failed"
    exit 1
fi


# Source the environment file
source ".env-${FULL_NAMESPACE}"

# Set image tag based on git branch
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$GIT_BRANCH" = "dockerify" ]; then
    export IMAGE_TAG="dockerify"
else
    export IMAGE_TAG="latest"
fi
echo "🏗️ Building image with tag ${IMAGE_TAG}"

# Run collector test
# Capture both exit code and output from collector_test.sh
collector_test_output=$(./collector_test.sh --env-file ".env-${FULL_NAMESPACE}")
test_result=$?

# Parse all needed values from the output at once
LOCAL_COLLECTOR_HOST=""
LOCAL_COLLECTOR_PORT=""
while IFS= read -r line; do
    case "$line" in
        *"LOCAL_COLLECTOR_HOST="*)
            LOCAL_COLLECTOR_HOST="${line#*=}"
            ;;
        *"LOCAL_COLLECTOR_PORT="*)
            LOCAL_COLLECTOR_PORT="${line#*=}"
            ;;
    esac
done <<< "$collector_test_output"

if [ $test_result -eq 101 ]; then
    echo "ℹ️  Starting new collector instance"
    COLLECTOR_PROFILE_STRING="--profile local-collector"
    
    # Define port range
    PORT_START=${LOCAL_COLLECTOR_PORT:-50051}
    PORT_END=51050
    
    # Find first available port in range
    port=$PORT_START
    while [ $port -le $PORT_END ]; do
        # Test port availability on localhost, 127.0.0.1, and 0.0.0.0
        port_in_use=0
        for ip in "localhost" "127.0.0.1" "0.0.0.0"; do
            nc -z "$ip" "$port" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                port_in_use=1
                break
            fi
        done
        
        if [ $port_in_use -eq 0 ]; then
            # Port is available on all interfaces
            export LOCAL_COLLECTOR_PORT=$port
            echo "✅ Using port $port for collector"
            break
        fi
        port=$((port + 1))
    done
    
    if [ $port -gt $PORT_END ]; then
        echo "❌ No available ports found in range to assign for local collector: $PORT_START-$PORT_END"
        exit 1
    fi
    
    # For new collector, construct the connection string
    export LOCAL_COLLECTOR_HOST="snapshotter-lite-local-collector-${SLOT_ID}-${FULL_NAMESPACE}@snapshotter-lite-v2-${SLOT_ID}-${FULL_NAMESPACE}"
elif [ $test_result -eq 100 ]; then
    echo "✅ Using existing collector instance"
    COLLECTOR_PROFILE_STRING=""
    # Export the collector connection from the test output
    if [ -n "$LOCAL_COLLECTOR_HOST" ]; then
        export LOCAL_COLLECTOR_HOST
        echo "✅ Using collector connection: $LOCAL_COLLECTOR_HOST"
    else
        echo "❌ Failed to get collector connection string"
        exit 1
    fi
fi

# insert into env file
# check if the config exists
# if it does, replace else insert
if grep -q "^LOCAL_COLLECTOR_HOST=" ".env-${FULL_NAMESPACE}"; then
    # Replace existing LOCAL_COLLECTOR_HOST line
    sed -i'.backup' "s|^LOCAL_COLLECTOR_HOST=.*|LOCAL_COLLECTOR_HOST=${LOCAL_COLLECTOR_HOST}|" ".env-${FULL_NAMESPACE}"
else
    # Append new LOCAL_COLLECTOR_HOST line
    echo "LOCAL_COLLECTOR_HOST=${LOCAL_COLLECTOR_HOST}" >> ".env-${FULL_NAMESPACE}"
fi

# replace or edit LOCAL_COLLECTOR_PORT similarly
if grep -q "^LOCAL_COLLECTOR_PORT=" ".env-${FULL_NAMESPACE}"; then
    # Replace existing LOCAL_COLLECTOR_PORT line
    sed -i'.backup' "s|^LOCAL_COLLECTOR_PORT=.*|LOCAL_COLLECTOR_PORT=${LOCAL_COLLECTOR_PORT}|" ".env-${FULL_NAMESPACE}"
else
    # Append new LOCAL_COLLECTOR_PORT line
    echo "LOCAL_COLLECTOR_PORT=${LOCAL_COLLECTOR_PORT}" >> ".env-${FULL_NAMESPACE}"
fi

source ".env-${FULL_NAMESPACE}"
# Create lowercase versions of namespace variables
PROJECT_NAME="snapshotter-lite-v2-${SLOT_ID}-${FULL_NAMESPACE}"
PROJECT_NAME_LOWER=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')
FULL_NAMESPACE_LOWER=$(echo "$FULL_NAMESPACE" | tr '[:upper:]' '[:lower:]')
export CRON_RESTART=${CRON_RESTART:-false}

# Export the lowercase version for docker-compose
export FULL_NAMESPACE_LOWER

# Check if running in Windows Subsystem for Linux (WSL)
check_wsl() {
    if grep -qi microsoft /proc/version; then
        echo "🐧🪆 Running in WSL environment"
        return 0  # true in shell
    fi
    return 1  # false in shell
}

# Configure Docker Compose profiles based on WSL environment
if check_wsl; then
    # WSL environment - disable autoheal
    COMPOSE_PROFILES="${COLLECTOR_PROFILE_STRING}"
    export AUTOHEAL_LABEL=""
else
    # Non-WSL environment - enable autoheal
    COMPOSE_PROFILES="${COLLECTOR_PROFILE_STRING} --profile autoheal"
    export AUTOHEAL_LABEL="autoheal=true"
fi

# Modify the deploy-services call to use the profiles
./deploy-services.sh --env-file ".env-${FULL_NAMESPACE}" \
    --project-name "$PROJECT_NAME_LOWER" \
    --collector-profile "$COMPOSE_PROFILES" \
    --image-tag "$IMAGE_TAG"
