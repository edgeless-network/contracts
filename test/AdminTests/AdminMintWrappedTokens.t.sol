// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23 <0.9.0;

import "forge-std/src/Vm.sol";
import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { console2 } from "forge-std/src/console2.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";
import { StdUtils } from "forge-std/src/StdUtils.sol";

import { EdgelessDeposit } from "../../src/EdgelessDeposit.sol";
import { StakingManager } from "../../src/StakingManager.sol";
import { WrappedToken } from "../../src/WrappedToken.sol";
import { EthStrategy } from "../../src/strategies/EthStrategy.sol";
import { DaiStrategy } from "../../src/strategies/DaiStrategy.sol";

import { IDai } from "../../src/interfaces/IDai.sol";
import { IL1StandardBridge } from "../../src/interfaces/IL1StandardBridge.sol";
import { ILido } from "../../src/interfaces/ILido.sol";
import { IUsdt } from "../../src/interfaces/IUsdt.sol";
import { IUsdc } from "../../src/interfaces/IUsdc.sol";
import { IWithdrawalQueueERC721 } from "../../src/interfaces/IWithdrawalQueueERC721.sol";
import { IStakingStrategy } from "../../src/interfaces/IStakingStrategy.sol";
import { LIDO, Dai, Usdc, Usdt } from "../../src/Constants.sol";

import { Permit, SigUtils } from "../Utils/SigUtils.sol";
import { DeploymentUtils } from "../Utils/DeploymentUtils.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract AdminMintTests is PRBTest, StdCheats, StdUtils, DeploymentUtils {
    using SigUtils for Permit;

    EdgelessDeposit internal edgelessDeposit;
    WrappedToken internal wrappedEth;
    WrappedToken internal wrappedUSD;
    IL1StandardBridge internal l1standardBridge;
    StakingManager internal stakingManager;
    IStakingStrategy internal EthStakingStrategy;
    IStakingStrategy internal DaiStakingStrategy;

    address public constant STETH_WHALE = 0x5F6AE08B8AeB7078cf2F96AFb089D7c9f51DA47d; // Blast Deposits

    uint32 public constant FORK_BLOCK_NUMBER = 18_950_000;

    address public owner = makeAddr("Edgeless owner");
    address public depositor = makeAddr("Depositor");
    uint256 public depositorKey = uint256(keccak256(abi.encodePacked("Depositor")));
    address public staker = makeAddr("Staker");

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        vm.createSelectFork({
            urlOrAlias: string(abi.encodePacked("https://Eth-mainnet.g.alchemy.com/v2/", alchemyApiKey)),
            blockNumber: FORK_BLOCK_NUMBER
        });

        (stakingManager, edgelessDeposit, wrappedEth, wrappedUSD, EthStakingStrategy, DaiStakingStrategy) =
            deployContracts(owner, owner);
    }

    function mintStETH(address to, uint256 amount) internal {
        vm.startPrank(STETH_WHALE);
        LIDO.transfer(to, amount);
        vm.stopPrank();
    }

    function test_mintWrappedEthFromSteth(uint64 amount) external {
        vm.assume(amount != 0);
        mintStETH(address(EthStakingStrategy), amount);

        vm.startPrank(owner);
        edgelessDeposit.mintEthBasedOnStakedAmount(owner, amount);
        assertEq(wrappedEth.balanceOf(owner), amount);
    }

    function test_mintWrappedEthFromEth(uint64 amount) external {
        vm.assume(amount != 0);
        vm.deal(address(edgelessDeposit), amount);

        vm.startPrank(owner);
        edgelessDeposit.mintEthBasedOnStakedAmount(owner, amount);
        assertEq(wrappedEth.balanceOf(owner), amount);
    }

    function test_mintWrappedUSDFromDai(uint64 amount) external {
        amount = uint64(bound(amount, 1e18, type(uint64).max));
        deal(address(Dai), depositor, amount);

        vm.startPrank(depositor);
        Dai.approve(address(edgelessDeposit), amount);
        edgelessDeposit.depositDai(depositor, amount);
        vm.stopPrank();
        deal(address(Dai), address(DaiStakingStrategy), amount);
        vm.startPrank(owner);
        edgelessDeposit.mintUSDBasedOnStakedAmount(owner, amount);
        assertEq(wrappedUSD.balanceOf(owner), amount);
        assertEq(wrappedUSD.balanceOf(depositor), amount);
    }

    function test_mintWrappedEthFromEthandSteth(uint64 ethAmount, uint64 lidoAmount) external {
        vm.assume(ethAmount != 0 && lidoAmount != 0);

        uint96 total = uint96(ethAmount) + uint96(lidoAmount);

        vm.deal(address(edgelessDeposit), ethAmount);
        mintStETH(address(edgelessDeposit), lidoAmount);

        vm.startPrank(owner);
        edgelessDeposit.mintEthBasedOnStakedAmount(owner, total);
        assertEq(wrappedEth.balanceOf(owner), total);
    }
}
