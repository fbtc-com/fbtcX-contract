## FbtcX-contracts

The locked FBTC has been locked within partner applications, backed by native BTC held in a separate BTC address. Locked FBTC is created for dedicated partner protocols.

### Build

```shell
$ forge install OpenZeppelin/openzeppelin-contracts@v4.9.6 --no-commit
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

Bedrock 等通过 `TransparentUpgradeableProxy` 部署、且由 `TimelockController` 直接管理 proxy admin 的 lockedFBTC 实例，升级到 `LockedFBTCV2` 时请使用专用脚本和中文操作手册：[`script/LOCKED_FBTC_V2_UPGRADE.md`](script/LOCKED_FBTC_V2_UPGRADE.md)。该流程只升级指定代理，并在升级后向 Ethereum migrator 单独授予 `MIGRATOR_ROLE`。

专用脚本会校验 ERC-1967 implementation/admin/beacon 槽，并明确禁止把 Transparent 流程用于 `BeaconProxy`。Factory 创建的 Beacon 实例需要另行设计和审核共享 Beacon 升级流程。

以下是仓库原有的通用升级流程；升级 `LockedFBTCV2` 时应优先使用上述专用脚本：

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
