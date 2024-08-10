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
forge script script/deploy.s.sol:Deploy \
-s "$(cast calldata "deploy(string)" "$PROJECT_NAME")" \
-vvvvv \
--legacy \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
--verify \
--verifier-url "https://api.etherscan.io/api?" \
--broadcast \
--slow


# transfer all roles
forge script script/deploy.s.sol:Deploy \
-s "$(cast calldata "transferAllRoles(string)" "$PROJECT_NAME")" \
--legacy \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast \
--slow

# Check if the role transfer was successful
if [ $? -ne 0 ]; then
  echo "Role transfer failed"
  exit 1
fi

echo "Deployment and role transfer completed successfully"