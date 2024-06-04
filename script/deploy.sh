forge script script/deploy.s.sol:Deploy \
-s "deploy()" \
-vvvvv \
--priority-gas-price 0 \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
-g 600000 \
--broadcast