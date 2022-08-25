pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import {IProxyWalletFactory} from "../interfaces/IProxyWalletFactory.sol";
import {GSNLib} from "./GSNLib.sol";
import {RevertCaptureLib} from "../libraries/RevertCaptureLib.sol";
import {ProxyWalletLib} from "../ProxyWallet/ProxyWalletLib.sol";
import {IRootChain} from "../interfaces/IRootChain.sol";
import {FactoryLib} from "../libraries/FactoryLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GSNModule03 {
    using GSNLib for *;

    address public whitelistedRelayer;

    constructor(address _whitelistedRelayer) public {
        whitelistedRelayer = _whitelistedRelayer;
    }

    function acceptRelayedCall(
        address relay,
        address from,
        bytes memory encodedFunction,
        uint256, /* transactionFee */
        uint256, /* gasPrice */
        uint256, /* gasLimit */
        uint256, /* nonce */
        bytes memory, /* approvalData */
        uint256 /* maxPossibleCharge */
    ) public view returns (uint256 doCall, bytes memory) {
        (bytes4 signature, bytes memory args) = encodedFunction.splitPayload();
        // Allow whitelisted relayer to perform any proxy call
        if (
            signature == IProxyWalletFactory(0).proxy.selector &&
            relay == whitelistedRelayer
        ) {
            doCall = 0;
        } else doCall = 1;
    }

    function preRelayedCall(
        bytes memory /* context */
    ) public returns (bytes32) {}

    function postRelayedCall(
        bytes memory, /* context */
        bool, /* success */
        uint256, /* actualCharge */
        bytes32 /* preRetVal */
    ) public {}
}
