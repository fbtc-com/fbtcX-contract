// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { Request, UserInfo, RequestLib, Operation }  from "../Common.sol";

interface IFireBridge {

    /// @notice Initiate a FBTC minting request for the qualifiedUser.
    /// @param _amount The amount of FBTC to mint.
    /// @param _depositTxid The BTC deposit txid
    /// @param _outputIndex The transaction output index to user's deposit address.
    /// @return _hash The hash of the new created request.
    /// @return _r The full new created request.
    function addMintRequest(
        uint256 _amount,
        bytes32 _depositTxid,
        uint256 _outputIndex
    )external returns (bytes32 _hash, Request memory _r);

    /// @notice Initiate a FBTC burning request for the qualifiedUser.
    /// @param _amount The amount of FBTC to burn.
    /// @return _hash The hash of the new created request.
    /// @return _r The full new created request.
    function addBurnRequest(
        uint256 _amount
    )external returns (bytes32 _hash, Request memory _r);


}