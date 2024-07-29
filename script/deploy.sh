# mantle

forge script script/deploy.s.sol:Deploy \
-s "deploy()" \
-vvvvv \
--priority-gas-price 0 \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
-g 2000000 \
--broadcast

forge script script/deploy.s.sol:Deploy \
-s "transferAllRoles()" \
--priority-gas-price 0 \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
-g 2000000 \
--broadcast

# eth

forge script script/deploy.s.sol:Deploy \
-s "deploy()" \
-vvvvv \
--legacy \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast

forge script script/deploy.s.sol:Deploy \
-s "transferAllRoles()" \
--legacy \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast