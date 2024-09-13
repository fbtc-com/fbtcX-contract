# mantle

forge script script/DeployNFT.s.sol:DeployOnMultipleNetworks \
-s "run()" \
-vvvvv \
--rpc-url $RPC_URL_SEPOLIA \
--private-key $PRIVATE_KEY \
--broadcast \
--verify --verifier etherscan --chain-id 11155111 --etherscan-api-key $ETHERSCAN_API_KEY_SEPOLIA 



forge script script/DeployNFT.s.sol:DeployOnMultipleNetworks \
-s "run()" \
-vvvvv \
--rpc-url $RPC_URL_MANTLE_SEP \
--private-key $PRIVATE_KEY \
--broadcast \
--verify --verifier blockscout --verifier-url "https://explorer.sepolia.mantle.xyz/api?module=contract&action=verify"


# verify contract on sepolia
forge verify-contract \
    --chain-id 11155111 \
    --watch \
    --etherscan-api-key $ETHERSCAN_API_KEY_SEPOLIA \
    --constructor-args $(cast abi-encode "constructor(string,address)"  "https://static.testnet.mantle.xyz/fbtc/json/" 0xDCB1BC0618D5F009A4C3e76d877Bf89d7c215BA9) \
    0xB17047C50EbAFCDe58FbF4474d318Baa31A2e7da \
    src/FBTCIdentity.sol:Vulcan

# mint NFT
cast send 0xB17047C50EbAFCDe58FbF4474d318Baa31A2e7da "mint(address,uint256,uint256)" 0xF4D196938AC6f9f4a914DBcE5EAFe45E4895fdb5 1 1 \
--rpc-url $RPC_URL_MANTLE_SEP \
--private-key $PRIVATE_KEY

cast send 0xB17047C50EbAFCDe58FbF4474d318Baa31A2e7da "mint(address,uint256,uint256)" 0xF4D196938AC6f9f4a914DBcE5EAFe45E4895fdb5 1 1 \
--rpc-url $RPC_URL_SEPOLIA \
--private-key $PRIVATE_KEY
