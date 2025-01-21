#!/bin/bash

# Source environment variables
if [ -z "$FULL_NAMESPACE" ]; then
    echo "FULL_NAMESPACE not found, please run build.sh first to set up environment"
    exit 1  # it is fine to exit with 1 here, as setup should not proceed past this
fi

# parse --env-file argument
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --env-file) ENV_FILE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

source "$ENV_FILE"

# Set default values if not found in env
if [ -z "$LOCAL_COLLECTOR_PORT" ]; then
    export LOCAL_COLLECTOR_PORT=50051
fi

echo "🔄 Checking for existing collector..."

# Look for existing collector with matching namespace pattern
existing_collector=$(docker ps --format '{{.Names}}' | grep "snapshotter-lite-local-collector.*${FULL_NAMESPACE}" || true)

if [ -n "$existing_collector" ]; then
    echo "✅ Found existing collector: ${existing_collector} for data market namespace: ${FULL_NAMESPACE}"
    
    # Get network information and port mapping
    network_info=$(docker container inspect "$existing_collector" --format '{{range $net,$v := .NetworkSettings.Networks}}{{printf "%s\n" $net}}{{end}}' | head -n 1)
    # Get the first available host port binding (preferring IPv4)
    port_info=$(docker container inspect "$existing_collector" --format '{{range $p, $conf := .NetworkSettings.Ports}}{{range $conf}}{{if eq .HostIp "0.0.0.0"}}{{.HostPort}}{{end}}{{end}}{{end}}' | head -n 1)
    
    if [ -n "$network_info" ] && [ -n "$port_info" ]; then
        echo "✅ Using existing collector on network: $network_info with port: $port_info"
        # Export both connection string and port
        echo "LOCAL_COLLECTOR_HOST=${existing_collector}@${network_info}"
        echo "LOCAL_COLLECTOR_PORT=${port_info}"
        exit 100
    else
        echo "🟠 Could not determine existing network/port for collector in data market namespace: ${FULL_NAMESPACE}"
        exit 101
        echo "LOCAL_COLLECTOR_PORT=${LOCAL_COLLECTOR_PORT}"
    fi
else
    echo "⚠️ No active collector found for namespace: ${FULL_NAMESPACE}"
    exit 101
fi
