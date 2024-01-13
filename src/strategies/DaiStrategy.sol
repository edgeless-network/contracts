// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

import { DAI, DSR_MANAGER } from "../Constants.sol";

import { IStakingStrategy } from "../interfaces/IStakingStrategy.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { console2 } from "forge-std/src/console2.sol";

contract DaiStrategy is IStakingStrategy, OwnableUpgradeable {
    error InsufficientFunds();

    address public stakingManager;

    function initialize(address _owner, address _stakingManager) external initializer {
        stakingManager = _stakingManager;
        __Ownable_init(_owner);
    }

    function deposit(uint256 amount) external payable {
        DAI.transferFrom(msg.sender, address(this), amount);
        DAI.approve(address(DSR_MANAGER), amount);
        DSR_MANAGER.join(address(this), amount);
        // emit DaiStaked(amount);
    }

    function withdraw(uint256 amount) external returns (uint256 withdrawnAmount) {
        uint256 balanceBefore = DAI.balanceOf(address(this));
        DSR_MANAGER.exit(address(this), amount);
        uint256 balanceAfter = DAI.balanceOf(address(this));
        console2.log("stakingManager", stakingManager);
        DAI.transfer(stakingManager, DAI.balanceOf(address(this)));
        // emit DaiWithdrawn(withdrawnAmount);
        return balanceAfter - balanceBefore;
    }

    function underlyingAsset() external view returns (address) { }
    function underlyingAssetAmount() external view returns (uint256) { }
    function underlyingAssetAmountNoUpdate() external returns (uint256) { }
}
