## FbtcX-contracts

The locked FBTC has been locked within partner applications, backed by native BTC held in a separate BTC address. Locked FBTC is created for dedicated partner protocols.

### Build

```shell
$ forge install OpenZeppelin/openzeppelin-contracts --no-commit
$ forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.9.6 --no-commit
$ forge install foundry-rs/forge-std --no-commit

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

### Upgrading

Upgrade a contract to its new implementation in the `src/` directory. The script will deploy a new implementation contract but you can
control whether it **executes the upgrade** onchain with the named argument `execute`. Note that even if you call the upgrade with
`execute=false`, you **must** also include the `--broadcast` option as the implementation contract must be deployed for the eventual upgrade
to work.

**`execute=false`**

```shell

forge script script/Upgrade.s.sol:Upgrade \
-s "upgrade(string, bool)" 'LockedFBTC' false \
-vvvvv \
--priority-gas-price 0 \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
-g 700000 \
--broadcast

```

Deploys the implementation contract and logs the byte encoded `TimelockController` upgrade call (calldata to schedule and execute) instead of performing the upgrade. This
is required if the **upgrader** is a multisig. To use, copy the calldata and execute a multisig transaction where the logged `ProxyAdmin`
address is the `to` value and the calldata is the `data` value.

**`execute=true`**

```shell

forge script script/Upgrade.s.sol:Upgrade \
-s "upgrade(string, bool)" 'LockedFBTC' true \
-vvvvv \
--priority-gas-price 0 \
--rpc-url $FOUNDRY_RPC_URL \
--private-key $PRIVATE_KEY \
-g 700000 \
--broadcast

```

Deploys the implementation contract and executes the upgrade transaction onchain. It's useful for testing networks, like Goerli, where an EOA is the **upgrader**.


### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
