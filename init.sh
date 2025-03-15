#!/bin/bash

export PROTOCOL_STATE_CONTRACT="0x670E0Cf8c8dF15B326D5E2Db4982172Ff8504909"
export PROST_RPC_URL="https://rpc.powerloom.network"
export PROST_CHAIN_ID=7865
export POWERLOOM_CHAIN=mainnet
export SOURCE_CHAIN=ETH
export FULL_NAMESPACE="${POWERLOOM_CHAIN}-${NAMESPACE}-${SOURCE_CHAIN}"

source .env-${FULL_NAMESPACE}

echo "📦 Cloning fresh config repo..."
git clone $SNAPSHOT_CONFIG_REPO "config"
cd config
git checkout $SNAPSHOT_CONFIG_REPO_BRANCH
cd ..

echo "📦 Cloning fresh compute repo..."
git clone $SNAPSHOTTER_COMPUTE_REPO "computes"
cd computes
git checkout $SNAPSHOTTER_COMPUTE_REPO_BRANCH
cd ..

bash snapshotter_autofill.sh

if [ $? -ne 0 ]; then
    echo "❌ Config setup failed"
    exit 1
fi

# Continue with existing steps
# poetry run python -m snapshotter.snapshotter_id_ping
# ret_status=$?

# if [ $ret_status -ne 0 ]; then
#     echo "Snapshotter identity check failed on protocol smart contract"
#     exit 1
# fi

poetry run python -m snapshotter.system_event_detector