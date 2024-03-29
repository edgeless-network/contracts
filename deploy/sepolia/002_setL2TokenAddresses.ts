import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre
    const { getOrNull, execute, log } = deployments
    const { deployer, l2Eth, l2USD } = await getNamedAccounts()

    const EdgelessDeposit = await getOrNull("EdgelessDeposit");
    if (EdgelessDeposit) {
        // await execute("EdgelessDeposit", { from: deployer, log: true }, "setL2Eth", l2Eth);
        await execute("EdgelessDeposit", { from: deployer, log: true }, "setL2USD", l2USD);
    } else {
        log("EdgelessDeposit not found, make sure to deploy it first");
    }
};

export default func;
// func.skip = async () => true;
