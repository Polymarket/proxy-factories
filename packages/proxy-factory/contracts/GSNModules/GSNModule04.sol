pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import {IProxyWalletFactory} from "../interfaces/IProxyWalletFactory.sol";
import {GSNLib} from "./GSNLib.sol";
import {RevertCaptureLib} from "../libraries/RevertCaptureLib.sol";
import {ProxyWalletLib} from "../ProxyWallet/ProxyWalletLib.sol";
import {IRootChain} from "../interfaces/IRootChain.sol";
import {FactoryLib} from "../libraries/FactoryLib.sol";
import { Math } from "@openzeppelin/contracts/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/ownership/Ownable.sol";
import { IChi } from "../interfaces/IChi.sol";

contract GSNModule04 is Ownable {
    using GSNLib for *;
    address public whitelistedRelayer;
    address constant CHI_TOKEN = 0x0000000000004946c0e9F43F4Dee607b0eF1fA1c;
    // Maximum amount of CHI to burn
    uint256 constant MAX_BURN_AMOUNT = 8;

    constructor(address _whitelistedRelayer) public Ownable() {
        whitelistedRelayer = _whitelistedRelayer;
        // Prefill all slots with current gas price
        for (uint256 i = 0; i < AVERAGE_N_RECORDS; i++) {
            _storeThisGasPrice();
        }
    }

    function _getGSNModule() internal view returns (GSNModule04 gsnModule) {
        gsnModule = GSNModule04(ProxyWalletLib.getGSNModule());
    }

    function _getChiAddress() public view returns (address) {
        return CHI_TOKEN;
    }

    bytes32 constant GAS_PRICE_STORAGE_SLOT =
        0x6176eedb4178e8eb1b4156527c106860b74026ff26f7dbc11da0c373efba968a; // keccak256("gasprice")
    bytes32 constant GAS_PRICE_NEXT_POSITION_SLOT =
        0x69cf67c52ac5c3626369a2c4ce103b3fffd46fa4d3948f125cbfdc25a5f01d2c; // keccak256("gasprice-length")
    uint256 constant AVERAGE_N_RECORDS = 5;

    function _storeNextGasPricePosition(uint256 length) internal {
        bytes32 slot = GAS_PRICE_NEXT_POSITION_SLOT;
        assembly {
            sstore(slot, length)
        }
    }

    function _readNextGasPricePosition() public view returns (uint256 length) {
        bytes32 slot = GAS_PRICE_NEXT_POSITION_SLOT;
        assembly {
            length := sload(slot)
        }
    }

    function _storeGasPrice(
        uint256 i,
        uint256 gasPrice
    ) internal {
        bytes32 slot = keccak256(abi.encodePacked(GAS_PRICE_STORAGE_SLOT, i));
        assembly {
            sstore(slot, gasPrice)
        }
    }

    function _readGasPrice(uint256 i)
        public
        view
        returns (uint256 gasPrice)
    {
        bytes32 slot = keccak256(abi.encodePacked(GAS_PRICE_STORAGE_SLOT, i));
        assembly {
            gasPrice := sload(slot)
        }
    }

    function _storeThisGasPrice() internal {
        // Get the index of the slot to store gas price in
        uint256 position = _readNextGasPricePosition();
        _storeGasPrice(position, tx.gasprice);
        // Rotate through every AVERAGE_N_RECORDS slots
        _storeNextGasPricePosition((position + 1) % AVERAGE_N_RECORDS);
    }

    function _getMeanGasPrice() public view returns (uint256 result) {
        uint256 sum;
        for (uint256 i = 0; i < AVERAGE_N_RECORDS; i++) {
            uint256 gasPrice = _readGasPrice(i);
            sum += gasPrice;
        }
        result = sum / AVERAGE_N_RECORDS;
    }

    bytes32 constant GASPRICE_THRESHOLD_SLOT =
        0x07350205221d0ce9cc016414b10dfaac01bc9c2a8ddbb38c7fb370049017d90d; // keccak256("gasprice.threshold")

    function setGasPriceThreshold(uint256 threshold) public onlyOwner {
        bytes32 slot = GASPRICE_THRESHOLD_SLOT;
        assembly {
            sstore(slot, threshold)
        }
    }

    function getGasPriceThresholdHandler() public view returns (uint256 threshold) {
        bytes32 slot = GASPRICE_THRESHOLD_SLOT;
        assembly {
            threshold := sload(slot)
        }
    }

    function getGasPriceThreshold() public view returns (uint256 threshold) {
        return _getGSNModule().getGasPriceThresholdHandler();
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
        address _whitelistedRelayer = whitelistedRelayer; // save 800 gas
        if (
            signature == IProxyWalletFactory(0).proxy.selector &&
            (relay == _whitelistedRelayer || _whitelistedRelayer == address(0x0))) {
            doCall = 0;
        } else doCall = 1;
    }

    function preRelayedCall(
        bytes memory /* context */
    ) public returns (bytes32) {
        _storeThisGasPrice();
    }

    function postRelayedCall(
        bytes memory, /* context */
        bool, /* success */
        uint256 gasAmount,
        bytes32 /* preRetVal */
    ) public {
        // If moving average of past 5 txs' gas prices is above threshold
        if (_getMeanGasPrice() >= getGasPriceThreshold()) {
            // Burn Chi to reduce gas costs
            IChi(_getChiAddress()).freeUpTo(
                Math.min((gasAmount + 14154) / 41947, MAX_BURN_AMOUNT)
            ); // divide by twice the max gasrefund Chi token qty since we can only get 50% refunded
        }
    }
}
