## FbtcX-contracts

The locked FBTC has been locked within partner applications, backed by native BTC held in a separate BTC address. Locked FBTC is created for dedicated partner protocols.

### Build

```shell
$ forge install OpenZeppelin/openzeppelin-contracts@v4.9.6 --no-commit
$ forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.9.6 --no-commit

$ forge build
```

### Test

```shell
$ forge test
```

### Deploy

```shell
forge script script/deploy.s.sol:Deploy \
    -s "deploy()" \
    -vvvvv \
    --priority-gas-price 0 \
    --rpc-url $FOUNDRY_RPC_URL \
    --private-key $PRIVATE_KEY \
    -g 700000 \
    --broadcast
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
