# mantle

forge script script/DeployNFT.s.sol:DeployOnMultipleNetworks \
-s "run()" \
-vvvvv \
--rpc-url $RPC_URL_SEPOLIA \
--private-key $PRIVATE_KEY \
--broadcast \
--gas-limit 4000000 \
--gas-price 20000000000 \
--verify --verifier etherscan --chain-id 11155111 --etherscan-api-key $ETHERSCAN_API_KEY_SEPOLIA 



forge script script/DeployNFT.s.sol:DeployOnMultipleNetworks \
-s "run()" \
-vvvvv \
--rpc-url $RPC_URL_MANTLE_SEP \
--private-key $PRIVATE_KEY \
--broadcast \
--gas-limit 3572982 \
--gas-price 19103695761 \
--verify --verifier blockscout --verifier-url "https://explorer.sepolia.mantle.xyz/api?module=contract&action=verify"


# verify contract on sepolia
forge verify-contract \
    --chain-id 11155111 \
    --watch \
    --etherscan-api-key $ETHERSCAN_API_KEY_SEPOLIA \
    --constructor-args $(cast abi-encode "constructor(string,address)"  $BASEURL $OWNER) \
    0x526429b9C6266f2021473215b441eE2DC3684B84 \
    src/FBTCIdentity.sol:FBTCBadge

# mint NFT
cast send 0xB17047C50EbAFCDe58FbF4474d318Baa31A2e7da "mint(address,uint256,uint256)" 0xeFB404f5E057eB57C0Cf960F07983De6895EC900 1 5 \
--rpc-url $RPC_URL_MANTLE_SEP \
--private-key $PRIVATE_KEY

cast send 0xB17047C50EbAFCDe58FbF4474d318Baa31A2e7da "mint(address,uint256,uint256)" 0xeFB404f5E057eB57C0Cf960F07983De6895EC900 1 5 \
--rpc-url $RPC_URL_SEPOLIA \
--private-key $PRIVATE_KEY