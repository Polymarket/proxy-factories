pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import {IProxyWalletFactory} from "../interfaces/IProxyWalletFactory.sol";
import {GSNLib} from "./GSNLib.sol";
import {RevertCaptureLib} from "../libraries/RevertCaptureLib.sol";
import {ProxyWalletLib} from "../ProxyWallet/ProxyWalletLib.sol";
import {IRootChain} from "../interfaces/IRootChain.sol";
import {FactoryLib} from "../libraries/FactoryLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GSNModule02 {
    using GSNLib for *;

    /**
     * @notice decodes bytes data into structured ProxyCalls
     * @param data - encoded ProxyCalls
     * @return array of decoded ProxyCalls
     */
    function decodeProxyCalls(bytes memory data)
        internal
        pure
        returns (ProxyWalletLib.ProxyCall[] memory calls)
    {
        calls = abi.decode(data, (ProxyWalletLib.ProxyCall[]));
    }

    // For addresses see: https://github.com/maticnetwork/static/blob/24a5fa08016d1dc866e7eba4e51b2b606c3e7539/network/mainnet/v1/index.json
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DEPOSIT_APPROVAL_TARGET = 0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf; // ERC20PredicateProxy
    address constant ROOT_CHAIN_ADDRESS = 0xA0c68C638235ee32657e8f720a23ceC1bFc77C77; // RootChainManagerProxy

    /**
     * @dev validate that the proxywallet is making a transfer call to USDC contract which will succeed
     * @param from - address of proxyWallet which will be making this call
     * @param proxyCall - call transaction which proxyWallet wants to make
     * @return GSN approval code representing whether to accept this transaction
     */
    function validateSingleCall(address from, ProxyWalletLib.ProxyCall memory proxyCall)
        internal
        view
        returns (uint256 code)
    {
        (bytes4 signature, bytes memory args) = proxyCall.data.splitPayload();
        // Reject if call isn't to transfer function on USDC contract
        if (
            proxyCall.typeCode == ProxyWalletLib.CallType.CALL &&
            proxyCall.to == USDC_ADDRESS &&
            signature == IERC20(0).transfer.selector
        ) {
            (, uint256 amount) = abi.decode(args, (address, uint256));
            // Reject if proxyWallet doesn't have enough funds
            if (IERC20(USDC_ADDRESS).balanceOf(from) < amount || amount == 0) code = 1;
            else code = 0;
        } else code = 1;
    }

    /**
     * @param from - address for which to return usdc balance
     * @return usdc balance of from
     */
    function getUSDCBalance(address from) internal view returns (uint256) {
        return IERC20(USDC_ADDRESS).balanceOf(from);
    }

    /**
     * @dev validate that the proxywallet is making exit and transfer calls to move funds back across bridge
     * @param calls - call transactions which proxyWallet wants to make
     * @return GSN approval code representing whether to accept this transaction
     */
    function validateWithdrawCalls(ProxyWalletLib.ProxyCall[] memory calls)
        internal
        view
        returns (uint256 code)
    {
        ProxyWalletLib.ProxyCall memory firstCall = calls[0];
        ProxyWalletLib.ProxyCall memory secondCall = calls[1];

        // Reject if first call isn't to exit funds from rootChainManager
        if (
            firstCall.typeCode != ProxyWalletLib.CallType.CALL ||
            firstCall.to != ROOT_CHAIN_ADDRESS
        ) return 1;

        // We can't reuse validateSingleCall as we do not yet know whether the withdrawal will cover the transfer
        (bytes4 secondSignature, bytes memory secondArgs) = secondCall
            .data
            .splitPayload();
        // Reject if call isn't to transfer function on USDC contract
        if (
            secondCall.typeCode == ProxyWalletLib.CallType.CALL &&
            secondCall.to == USDC_ADDRESS &&
            secondSignature == IERC20(0).transfer.selector
        ) {
            (, uint256 amount) = abi.decode(secondArgs, (address, uint256));
            // Reject if trying to transfer 0 USDC
            if (amount == 0) code = 1;
            else code = 0;
        } else code = 1;
    }

    /**
     * @dev validate that the proxywallet is making approve and depositFor calls to move funds across bridge which will succeed
     * @param from - address of proxyWallet which will be making this call
     * @param calls - call transactions which proxyWallet wants to make
     * @return GSN approval code representing whether to accept this transaction
     */
    function validateDepositCalls(address from, ProxyWalletLib.ProxyCall[] memory calls)
        internal
        view
        returns (uint256 code)
    {
        ProxyWalletLib.ProxyCall memory firstCall = calls[0];
        ProxyWalletLib.ProxyCall memory secondCall = calls[1];
        uint256 amountApproved;

        (bytes4 firstSignature, bytes memory firstArgs) = firstCall.data.splitPayload();
        (bytes4 secondSignature, bytes memory secondArgs) = secondCall
            .data
            .splitPayload();
        // Reject if first call isn't to approve function on USDC contract
        if (
            firstSignature == IERC20(0).approve.selector &&
            firstCall.typeCode == ProxyWalletLib.CallType.CALL &&
            firstCall.to == USDC_ADDRESS
        ) {
            (address target, uint256 amount) = abi.decode(
                firstArgs,
                (address, uint256)
            );
            amountApproved = amount;
            // Reject if not approving the rootChainManager to move funds
            if (target != DEPOSIT_APPROVAL_TARGET) {
                return 1;
            }
        } else return 1;

        // Reject if second call isn't to depositFor function on rootChainManager contract
        if (
            secondSignature == IRootChain(0).depositFor.selector &&
            secondCall.typeCode == ProxyWalletLib.CallType.CALL &&
            secondCall.to == ROOT_CHAIN_ADDRESS
        ) {
            (address user, address rootToken, bytes memory extraData) = abi.decode(
                secondArgs,
                (address, address, bytes)
            );
            // Reject depositing to a different address on matic, not depositing USDC or incorrect deposit data
            if ((user != from && rootToken != USDC_ADDRESS) || extraData.length != 0x20)
                return 1;
            uint256 amountToDeposit = abi.decode(extraData, (uint256));
            // Reject if proxyWallet doesn't have enough funds
            if (getUSDCBalance(from) < amountToDeposit) return 1;
            // Reject if rootChainManager isn't approved to take funds or deposit is zero
            if (amountToDeposit > amountApproved || amountToDeposit == 0) return 1;
        } else return 1;

        return 0;
    }

    /**
     * @dev calculate proxyWallet address of provided address
     * @param sender - address who's transaction is being relayed (i.e. not the relayer)
     * @return address of sender's proxyWallet
     */
    function toProxyWalletAddress(address sender) internal view returns (address) {
        address implementation = IProxyWalletFactory(msg.sender).getImplementation();
        return
            FactoryLib.deriveInstanceAddress(
                msg.sender,
                implementation,
                keccak256(abi.encodePacked(sender))
            );
    }

    function acceptRelayedCall(
        address, /* relay */
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
        if (signature == IProxyWalletFactory(0).proxy.selector) {
            address proxyAddress = toProxyWalletAddress(from);
            ProxyWalletLib.ProxyCall[] memory calls = decodeProxyCalls(args);
            if (calls.length == 1) {
                // erc20 transfer
                doCall = validateSingleCall(proxyAddress, calls[0]);
            } else if (calls.length == 2) {
                if (calls[0].to == USDC_ADDRESS) {
                    // erc20 approve + depositFor on matic bridge
                    doCall = validateDepositCalls(proxyAddress, calls);
                } else {
                    // exit on matic bridge + erc20 transfer
                    doCall = validateWithdrawCalls(calls);
                }
            } else doCall = 1;
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
