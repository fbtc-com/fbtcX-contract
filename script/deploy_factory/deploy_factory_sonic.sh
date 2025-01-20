#!/bin/bash

# Ensure that the project name parameter is passed
if [ -z "$1" ]; then
  echo "Usage: $0 <ProjectName>"
  exit 1
fi

PROJECT_NAME=$1

# Load environment variables from .env file
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
else
  echo ".env file not found!"
  exit 1
fi

# Ensure that the deployment folder exists
DEPLOYMENTS_DIR="./deployments/$PROJECT_NAME"
if [ ! -d "$DEPLOYMENTS_DIR" ]; then
  mkdir -p "$DEPLOYMENTS_DIR"
fi

# Execute deployment scripts
forge script script/factoryDeploy.s.sol:Deploy \
-s "$(cast calldata "deploy(string)" "$PROJECT_NAME")" \
--rpc-url $FOUNDRY_RPC_URL \
--gas-price 100000000 \
--private-key $PRIVATE_KEY \
--verify \
--broadcast \
--slow \
--timeout 600

echo "Deployment completed successfully"