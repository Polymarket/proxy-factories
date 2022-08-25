pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import { GSNRecipient } from "@openzeppelin/contracts/GSN/GSNRecipient.sol";
import { Ownable } from "@openzeppelin/contracts/ownership/Ownable.sol";
import { ERC1155TokenReceiver } from "@gnosis.pm/conditional-tokens-contracts/contracts/ERC1155/ERC1155TokenReceiver.sol";
import { Create2 } from "openzeppelin-solidity/contracts/utils/Create2.sol";
import { RevertCaptureLib } from "../libraries/RevertCaptureLib.sol";
import { ProxyWalletLib } from "./ProxyWalletLib.sol";
import { ProxyWallet } from "./ProxyWallet.sol";
import { FactoryLib } from "../libraries/FactoryLib.sol";
import { GSNLib } from "../GSNModules/GSNLib.sol";
import { GSNModule01 } from "../GSNModules/GSNModule01.sol";
import { IGSNModule } from "../interfaces/IGSNModule.sol";

contract ProxyWalletFactory is Ownable, GSNRecipient {
  using GSNLib for *;

  constructor() Ownable() public {
    ProxyWalletLib.setImplementation(deployImplementation());
    ProxyWalletLib.setGSNModule(address(new GSNModule01()));
  }

  /**
    * @notice Updates the GSN module to be used
    *
    * @param gsnModule - address of the new GSN module
    */
  function setGSNModule(address gsnModule) public onlyOwner {
    return ProxyWalletLib.setGSNModule(gsnModule);
  }

  /**
    * @notice Returns the address of the currently used GSN module
    */
  function getGSNModule() public view returns (address) {
    return ProxyWalletLib.getGSNModule();
  }

  /**
    * @notice Returns the address of the implementation of the proxy wallet
    */
  function getImplementation() public view returns (address) {
    return ProxyWalletLib.getImplementation();
  }

  /**
    * @notice Deploys the initial implementation of the proxy wallet which is to be cloned
    */
  function deployImplementation() internal returns (address) {
    return Create2.deploy(ProxyWalletLib.WALLET_FACTORY_SALT(), type(ProxyWallet).creationCode);
  }

  function _preRelayedCall(bytes memory context) internal returns (bytes32 returnData) {
    (bool success, bytes memory retval) = ProxyWalletLib.getGSNModule().delegatecall(abi.encodeWithSelector(IGSNModule(0).preRelayedCall.selector, context));
    if (!success) revert(RevertCaptureLib.decodeError(retval));
    (returnData) = abi.decode(retval, (bytes32));
  }
  function _postRelayedCall(bytes memory context, bool success, uint256 actualCharge, bytes32 preRetVal) internal {
    (bool success, bytes memory retval) = ProxyWalletLib.getGSNModule().delegatecall(abi.encodeWithSelector(IGSNModule(0).postRelayedCall.selector, context, success, actualCharge, preRetVal));
    if (!success) revert(RevertCaptureLib.decodeError(retval));
    return;
  }
  function acceptRelayedCall(
    address /* relay */,
    address /* from */,
    bytes memory /* encodedFunction */,
    uint256 /* transactionFee */,
    uint256 /* gasPrice */,
    uint256 /* gasLimit */,
    uint256 /* nonce */,
    bytes memory /* approvalData */,
    uint256 /* maxPossibleCharge */
  ) public view returns (uint256 doCall, bytes memory context) {
    (bool success, bytes memory retval) = ProxyWalletLib.getGSNModule().staticcall(msg.data);
    if (!success) revert(RevertCaptureLib.decodeError(retval));
    (doCall, context) = abi.decode(retval, (uint256, bytes));
  }

  /**
    * @notice Creates a proxy wallet for msgSender by cloning the one at _implementation
    *
    * @param _implementation - address of proxy wallet implementation to clone
    * @param msgSender - The address of the owner of the proxy wallet at instanceAddress
    */
  function makeWallet(address _implementation, address msgSender) internal returns (address user) {
    address payable clone = address(uint160(FactoryLib.create2Clone(_implementation, uint256(keccak256(abi.encodePacked(address(msgSender)))))));
    ProxyWallet(clone).initialize();
    return clone;
  }

  /**
    * @notice Checks if there already exists a proxy wallet for the provided msgSender. If so then do nothing, if not then create one.
    *
    * @param _implementation - address of proxy wallet implementation to clone
    * @param instanceAddress - The address at which the proxy wallet was (or will be) created
    * @param msgSender - The address of the owner of the proxy wallet at instanceAddress
    */
  function maybeMakeWallet(address _implementation, address instanceAddress, address msgSender) internal returns (address clone) {
    uint256 sz;
    assembly {
      sz := extcodesize(instanceAddress)
    }
    if (sz == 0) return makeWallet(_implementation, msgSender);
  }

  function cloneConstructor(bytes calldata /* consData */) external {}

  /**
    * @notice Fallback function.
    */
  function () external payable {
    // do nothing
  }

  /**
    * @notice Passes an array of contract calls from GSN relayer through to a proxy wallet. If the _msgSender does not own a wallet then one is created for them.
    *
    * @param calls - array of ProxyCalls which to pass along to the proxy wallet to be executed.
    */
  function proxy(ProxyWalletLib.ProxyCall[] memory calls) public payable returns (bytes[] memory returnValues) {
    address msgSender = _msgSender();
    address _implementation = ProxyWalletLib.getImplementation();
    address instanceAddress = FactoryLib.deriveInstanceAddress(_implementation, keccak256(abi.encodePacked(msgSender)));
    maybeMakeWallet(_implementation, instanceAddress, msgSender);
    returnValues = ProxyWallet(instanceAddress).proxy.value(msg.value)(calls);
  }
}
