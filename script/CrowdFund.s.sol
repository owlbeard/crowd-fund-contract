// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {CrowdFund} from "../src/CrowdFund.sol";

contract DeployCrowdFund is Script {
    CrowdFund private crowdFund;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        crowdFund = new CrowdFund();
        vm.stopBroadcast();
    }
}
