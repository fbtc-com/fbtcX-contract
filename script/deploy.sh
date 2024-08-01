# mantle

forge script script/deploy.s.sol:Deploy \
-s "deploy()" \
-vvvvv \
--priority-gas-price 0 \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
-g 2000000 \
--verify \
--verifier blockscout \
--verifier-url "https://explorer.mantle.xyz/api?" \
--broadcast \
--slow

forge script script/deploy.s.sol:Deploy \
-s "transferAllRoles()" \
--priority-gas-price 0 \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
-g 2000000 \
--broadcast \
--slow

# eth

forge script script/deploy.s.sol:Deploy \
-s "deploy()" \
-vvvvv \
--legacy \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
--verify \
--verifier-url "https://api.etherscan.io/api?" \
--broadcast \
--slow

forge script script/deploy.s.sol:Deploy \
-s "transferAllRoles()" \
--legacy \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast \
--slow

# bsc

forge script script/deploy.s.sol:Deploy \
-s "deploy()" \
-vvvvv \
--legacy \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
--verify \
--verifier-url "https://api.bscscan.com/api?" \
--broadcast \
--slow

forge script script/deploy.s.sol:Deploy \
-s "transferAllRoles()" \
--legacy \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast \
--slow
