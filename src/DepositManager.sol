// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

import { DAI, LIDO, USDC, USDT, _RAY, CURVE_3POOL, PSM } from "./Constants.sol";
import { WrappedToken } from "./tokens/WrappedToken.sol";

import { MakerMath } from "./lib/MakerMath.sol";

/**
 * @title DepositManager
 * @notice DepositManager is a library of functions that take in an amount of ETH, USDC, USDT, or
 * DAI and calculates how much of the corresponding wrapped token to mint.
 */
contract DepositManager {
    uint256 public constant _BASIS_POINTS = 10_000;
    address public constant _INITIAL_TOKEN_HOLDER = 0x000000000000000000000000000000000000dEaD;

    int128 public constant _CURVE_DAI_INDEX = 0;
    int128 public constant _CURVE_USDT_INDEX = 2;
    uint256 public constant _INITIAL_DEPOSIT_AMOUNT = 1000;
    uint256 public constant _WAD = 10 ** 18;

    error InsufficientBalance();
    error ZeroAddress();
    error ZeroDeposit();

    /**
     * @notice Deposit Eth to the ETH pool
     * @dev Amount is msg.value
     * @return mintAmount Amount of wrapped tokens to mint
     */
    function _depositEth(uint256 amount) internal pure returns (uint256 mintAmount) {
        if (amount == 0) {
            revert ZeroDeposit();
        }
        return amount;
    }

    /**
     * @notice Swaps USDC for DAI
     * @dev USDC is converted to DAI using Maker PSM
     * @param usdcAmount Amount of USDC deposited for swapping
     * @return mintAmount Amount of wrapped tokens to mint
     */
    function _depositUSDC(uint256 usdcAmount, address stakingManager) internal returns (uint256 mintAmount) {
        if (usdcAmount == 0) {
            revert ZeroDeposit();
        }

        if (stakingManager == address(0)) {
            revert ZeroAddress();
        }
        uint256 wadAmount = MakerMath.usdToWad(usdcAmount);
        uint256 conversionFee = PSM.tin() * wadAmount / _WAD;
        mintAmount = wadAmount - conversionFee;

        USDC.transferFrom(msg.sender, address(this), usdcAmount);

        /* Convert USDC to DAI through MakerDAO Peg Stability Mechanism. */
        USDC.approve(PSM.gemJoin(), usdcAmount);
        PSM.sellGem(stakingManager, usdcAmount);
    }

    /**
     * @notice Swaps USDT for DAI
     * @dev USDT is converted to DAI using Curve 3Pool
     * @param usdtAmount Amount of USDT deposited for swapping
     * @param minDAIAmount Minimum DAI amount to accept when exchanging through Curve (wad)
     * @return mintAmount Amount of wrapped tokens to mint
     */
    function _depositUSDT(
        uint256 usdtAmount,
        uint256 minDAIAmount,
        address stakingManager
    )
        internal
        returns (uint256 mintAmount)
    {
        if (usdtAmount == 0) {
            revert ZeroDeposit();
        }
        if (stakingManager == address(0)) {
            revert ZeroAddress();
        }

        uint256 usdtBalance = USDT.balanceOf(address(this));
        USDT.transferFrom(msg.sender, address(this), usdtAmount);
        uint256 receivedUSDT = USDT.balanceOf(address(this)) - usdtBalance;

        /* Exchange USDT to DAI through the Curve 3Pool. */
        uint256 daiBalance = DAI.balanceOf(address(this));
        USDT.approve(address(CURVE_3POOL), receivedUSDT);
        CURVE_3POOL.exchange(_CURVE_USDT_INDEX, _CURVE_DAI_INDEX, receivedUSDT, minDAIAmount);

        /* The amount of DAI received in the exchange is uncertain due to slippage, so we must record the deposit after
        the exchange. */
        mintAmount = DAI.balanceOf(address(this)) - daiBalance;
        DAI.transfer(stakingManager, mintAmount);
    }

    /**
     * @notice Transfer DAI from the depositor to this contract
     * @param daiAmount Amount to deposit in DAI (wad)
     * @return mintAmount Amount of wrapped tokens to mint
     */
    function _depositDAI(uint256 daiAmount, address stakingManager) internal returns (uint256 mintAmount) {
        if (daiAmount == 0) {
            revert ZeroDeposit();
        }
        if (stakingManager == address(0)) {
            revert ZeroAddress();
        }
        DAI.transferFrom(msg.sender, stakingManager, daiAmount);
        return daiAmount;
    }

    /**
     * @notice Transfer StEth from the depositor to this contract
     * @param stEthAmount Amount to deposit in StEth
     * @return mintAmount Amount of wrapped tokens to mint
     */
    function _depositStEth(uint256 stEthAmount, address stakingManager) internal returns (uint256 mintAmount) {
        if (stEthAmount == 0) {
            revert ZeroDeposit();
        }
        if (stakingManager == address(0)) {
            revert ZeroAddress();
        }
        LIDO.transferFrom(msg.sender, stakingManager, stEthAmount);
        return stEthAmount;
    }
}
